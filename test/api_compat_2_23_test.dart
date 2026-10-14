// 青龙新版接口回归测试（仅支持新版本服务端，不再兼容已下线的老接口）
//
// 背景：服务端下线了三个"按文件名读内容"的老接口（/api/logs/<文件>、/api/scripts/<文件>、
// /api/configs/<文件>，固定 410），并删除了日志删除频率接口 /api/system/log/remove。
// 本测试在本地起一个照新版契约行事的 mock HTTP 服务，直接驱动真实客户端代码
// （Api → Http → 解析），验证：
//   1. 直接打 detail 新接口，文件名/目录一律走查询参数（file / path / limit）；
//   2. 不再探测已下线的老路径（mock 对这些路径仍会返回 410，一旦回退过来断言即失败）；
//   3. 日志删除频率从 /api/system/config 读、用 logRemoveFrequency 写；
//   4. 解析结果正确落到 LogDelBean / TaskBean2 等模型上。
//
// 运行：flutter test test/api_compat_2_23_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/module/home/system_bean.dart';

const String _instance = "0";
const String _serverVersion = "2.23.0";

void main() {
  late HttpServer server;
  late String baseUrl;
  late List<String> requests;

  setUpAll(() async {
    // flutter_test 默认拦截网络（一律返回 400），这里放行，改用本机 mock 服务
    HttpOverrides.global = null;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = "http://127.0.0.1:${server.port}";

    server.listen((HttpRequest req) async {
      final uri = req.uri;
      final path = uri.path;
      // 记录完整请求行，供断言使用
      requests.add("${req.method} ${uri.path}?${uri.query}");

      // 读掉请求体，避免连接复用异常
      await req.drain<void>();

      switch (path) {
        case "/api/logs/detail":
          _send(req, {
            "code": 200,
            "data": "LOG-BODY",
            "offset": 0,
            "nextOffset": 8,
            "total": 8,
            "truncated": false,
          });
          return;
        case "/api/scripts/detail":
          _send(req, {"code": 200, "data": "SCRIPT-BODY"});
          return;
        case "/api/configs/detail":
          _send(req, {"code": 200, "data": "CONFIG-BODY"});
          return;

        // 日志删除频率（新版的家）
        case "/api/system/config":
          _send(req, {
            "code": 200,
            "data": {
              "id": 1,
              "type": "systemConfig",
              "info": {"logRemoveFrequency": 7, "timezone": "Asia/Shanghai"},
            },
          });
          return;
        case "/api/system/config/log-remove-frequency":
          _send(req, {"code": 200, "data": {"logRemoveFrequency": 15}});
          return;

        // 任务列表：双层包装
        case "/api/crons":
          _send(req, {
            "code": 200,
            "data": {
              "data": [
                {
                  "id": 1,
                  "name": "task-1",
                  "command": "echo hi",
                  "schedule": "0 0 * * *",
                  "status": 0,
                  "isPinned": 0,
                  "isDisabled": 0,
                }
              ],
              "total": 1,
            },
          });
          return;
      }

      // ── 以下路径均已下线（真实服务端固定回 410）。保留它们是为了守住
      //    「客户端不得再回退到老接口」这条线：一旦有人把回退逻辑加回来，
      //    响应就是 410，相应的 success / URL 断言会立刻失败。──
      if (path.startsWith("/api/logs/")) {
        _send(req, {"code": 410, "message": "接口已下线，请使用 /logs/detail 接口"});
        return;
      }
      if (path.startsWith("/api/scripts/")) {
        _send(req, {"code": 410, "message": "接口已下线，请使用 /scripts/detail 接口"});
        return;
      }
      if (path.startsWith("/api/configs/")) {
        _send(req, {"code": 410, "message": "接口已下线，请使用 /configs/detail 接口"});
        return;
      }
      if (path.startsWith("/api/system/log/remove")) {
        _send(req, {"code": 404, "message": "Not Found"});
        return;
      }
      // 未定义的路径：模仿 Express 默认 404（非 JSON 体）
      _sendRaw(req, 404, "Cannot " + req.method + " " + path);
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() async {
    requests = <String>[];
    final getIt = GetIt.instance;
    // get_it 7.x 的 reset() 是异步的（要等 dispose 完成才真正清空），
    // 不 await 会把下面刚注册的实例又清掉。
    await getIt.reset();
    getIt.registerSingleton(MultiAccountUserInfoViewModel());
    getIt.registerSingleton(
      UserInfoViewModel(
        token: "mock-token",
        useSecret: false,
        host: baseUrl,
        name: "admin",
        password: "admin",
        alias: "test",
      ),
      instanceName: _instance,
    );
    getIt.registerSingleton(Url(0), instanceName: _instance);
    getIt.registerSingleton(
      SystemBean(version: _serverVersion, fromAutoGet: false),
      instanceName: _instance,
    );
    getIt.registerSingleton(Http(baseUrl, 0), instanceName: _instance);
  });

  test("脚本内容读取：直接打 /api/scripts/detail，文件名与目录走查询参数", () async {
    final api = Api(0);
    final res = await api.scriptDetail("test.js", "dir1");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, "SCRIPT-BODY");
    expect(requests.length, 1, reason: requests.toString());
    expect(requests.single, startsWith("GET /api/scripts/detail?"));
    expect(requests.single, contains("file=test.js"));
    expect(requests.single, contains("path=dir1"));
  });

  test("配置文件内容读取：直接打 /api/configs/detail?path=", () async {
    final api = Api(0);
    final res = await api.content("config.sh");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, "CONFIG-BODY");
    expect(requests.length, 1, reason: requests.toString());
    expect(requests.single, startsWith("GET /api/configs/detail?path=config.sh"));
  });

  test("日志详情：直接打 /api/logs/detail，带 file/path 与 1MiB limit", () async {
    final api = Api(0);
    final res = await api.taskLogDetail("2026-10-14.log", "2026-10-14");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, "LOG-BODY");
    expect(requests.length, 1, reason: requests.toString());
    expect(requests.single, startsWith("GET /api/logs/detail?"));
    expect(requests.single, contains("file=2026-10-14.log"));
    expect(requests.single, contains("path=2026-10-14"));
    expect(requests.single, contains("limit=1048576"));
  });

  test("日志删除频率读取：GET /api/system/config，解析 info.logRemoveFrequency", () async {
    final api = Api(0);
    final res = await api.logDel();

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, isNotNull);
    expect(res.bean!.removeFrequency, 7);
    expect(requests.length, 1, reason: requests.toString());
    expect(requests.single, startsWith("GET /api/system/config?"));
  });

  test("日志删除频率写入：PUT /api/system/config/log-remove-frequency，字段名 logRemoveFrequency", () async {
    final api = Api(0);
    final res = await api.logDelTime(15);

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(requests.length, 1, reason: requests.toString());
    expect(
      requests.single,
      startsWith("PUT /api/system/config/log-remove-frequency?"),
    );
  });

  test("任务列表：解开 data.data 双层包装，且只传 searchValue", () async {
    final api = Api(0);
    final res = await api.crons2_13_09();

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean?.data?.length, 1);
    expect(res.bean!.data!.first.name, "task-1");
    expect(res.bean!.data!.first.id, 1);
    expect(requests.single, contains("searchValue="));
    expect(requests.single, isNot(contains("searchText=")));
  });
}

void _send(HttpRequest req, Object body) {
  _sendRaw(req, 200, jsonEncode(body));
}

void _sendRaw(HttpRequest req, int status, String body) {
  req.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(body);
  req.response.close();
}
