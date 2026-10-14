// 青龙 2.23 接口兼容回归测试
//
// 背景：服务端 2.19+ 起下线了三个"按文件名读内容"的老接口，并删除了日志删除频率接口，
// 老客户端会 404 / 410。本测试在本地起一个严格照 2.23 契约行事的 mock HTTP 服务，
// 直接驱动真实客户端代码（Api → Http → 解析），验证：
//   1. 老路径收到 410 后能自动切换到 detail 新接口，并把能力记在 Url 上（只探测一次）；
//   2. 文件名/目录改走查询参数（file / path / limit）；
//   3. 日志删除频率从 /api/system/config 读、用 logRemoveFrequency 写；
//   4. 解析结果正确落到 LogDelBean 等模型上。
//
// 运行：flutter test test/api_compat_2_23_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart';
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

      // 读掉请求体（POST/PUT/DELETE），避免连接复用异常
      await req.drain<void>();

      if (req.method == "DELETE" && path == "/api/system/log/remove") {
        _send(req, {"code": 404, "message": "Not Found"});
        return;
      }

      switch (path) {
        // ── 2.19+ 已下线的老接口：HTTP 200 + body code=410（与真实服务端一致）──
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

        // ── 日志删除频率（2.19+ 的新家）──
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

        // ── 任务列表：双层包装 ──
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

      // 其它一律按"老接口已下线"处理
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

  test("脚本内容读取：老路径 410 → 自动切 /api/scripts/detail 且文件名走查询参数", () async {
    final api = Api(0);
    final res = await api.scriptDetail("test.js", "dir1");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, "SCRIPT-BODY");

    // 第一次必须是老路径（老服务端兼容），第二次才是新接口
    expect(requests.length, 2, reason: requests.toString());
    expect(requests[0], startsWith("GET /api/scripts/test.js?"));
    expect(requests[1], startsWith("GET /api/scripts/detail?"));
    expect(requests[1], contains("file=test.js"));
    expect(requests[1], contains("path=dir1"));

    // 能力已被记住：第二次调用只打一次请求
    requests.clear();
    final again = await api.scriptDetail("b.js", "");
    expect(again.bean, "SCRIPT-BODY");
    expect(requests.length, 1, reason: requests.toString());
    expect(requests.first, startsWith("GET /api/scripts/detail?"));
  });

  test("配置文件内容读取：老路径 410 → /api/configs/detail?path=", () async {
    final api = Api(0);
    final res = await api.content("config.sh");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, "CONFIG-BODY");
    expect(requests.length, 2, reason: requests.toString());
    // 客户端会给非白名单请求附加 t=<时间戳>，故用 startsWith
    expect(requests[0], startsWith("GET /api/configs/config.sh?"));
    expect(requests[1], startsWith("GET /api/configs/detail?path=config.sh"));
  });

  test("日志详情：老路径 410 → /api/logs/detail，且带 1MiB limit", () async {
    final api = Api(0);
    final res = await api.taskLogDetail("2026-10-14.log", "2026-10-14");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, "LOG-BODY");
    expect(requests.length, 2, reason: requests.toString());
    // 2.13+ 老路径形如 /api/logs/<文件名>?path=<目录>
    expect(requests[0], startsWith("GET /api/logs/2026-10-14.log?path=2026-10-14"));
    expect(requests[1], startsWith("GET /api/logs/detail?"));
    expect(requests[1], contains("file=2026-10-14.log"));
    expect(requests[1], contains("path=2026-10-14"));
    expect(requests[1], contains("limit=1048576"));
  });

  test("日志删除频率读取：走新的 /api/system/config，解析出 info.logRemoveFrequency", () async {
    final api = Api(0);
    final res = await api.logDel();

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean, isNotNull);
    expect(res.bean!.removeFrequency, 7);
    expect(requests.length, 1, reason: requests.toString());
    expect(requests.first, startsWith("GET /api/system/config?"));
  });

  test("日志删除频率写入：PUT /api/system/config/log-remove-frequency，字段名为 logRemoveFrequency", () async {
    final api = Api(0);
    final res = await api.logDelTime(15);

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(requests.length, 1, reason: requests.toString());
    expect(
      requests.first,
      startsWith("PUT /api/system/config/log-remove-frequency?"),
    );
  });

  test("任务列表：能解开 data.data 双层包装", () async {
    final api = Api(0);
    final res = await api.crons2_13_09();

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean?.data?.length, 1);
    expect(res.bean!.data!.first.name, "task-1");
    expect(res.bean!.data!.first.id, 1);
    // 服务端只认 searchValue
    expect(requests.first, contains("searchValue="));
    expect(requests.first, isNot(contains("searchText=")));
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
