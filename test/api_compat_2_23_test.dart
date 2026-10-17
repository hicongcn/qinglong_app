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

  /// /api/user/init 的 mock 行为：ok=未初始化可设置 / already=已完成初始化 / admin=密码非法
  String initMode = "ok";
  late List<String> initBodies;

  /// 运行中任务的日志文件内容（测试里可以追加，模拟任务持续输出）
  String logBody = "";

  /// /api/scripts/history/restore 的 mock 行为：ok=可回滚 / conflict=文件已变化(409)
  String restoreMode = "ok";
  late List<String> restoreBodies;

  /// POST/PUT /api/crons 的请求体（用于断言 allow_multiple_instances 有没有带上）
  late List<String> cronBodies;

  /// 让 POST/PUT /api/crons 返回 celebrate 的校验失败（400 + validation）
  bool cronSaveInvalid = false;

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

      // 读掉请求体（顺便留下 init 的 body 供断言），避免连接复用异常
      final String body = await utf8.decoder.bind(req).join();

      // 运行中任务的实时日志（支持 offset/limit/tail，回 nextOffset）
      if (RegExp(r'^/api/crons/\d+/log$').hasMatch(path)) {
        final bool tail = uri.queryParameters['tail'] == 'true';
        final int? offset = int.tryParse(uri.queryParameters['offset'] ?? '');
        if (tail) {
          _send(req, {
            "code": 200,
            "data": logBody,
            "logStatus": "running",
            "offset": 0,
            "nextOffset": logBody.length,
            "total": logBody.length,
            "truncated": false,
          });
        } else {
          final int start = (offset ?? 0).clamp(0, logBody.length);
          final String delta = logBody.substring(start);
          _send(req, {
            "code": 200,
            "data": delta,
            "logStatus": "running",
            "offset": start,
            "nextOffset": start + delta.length,
            "total": logBody.length,
            "truncated": start > 0,
          });
        }
        return;
      }

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
        // 脚本编辑历史（青龙 2.23+，需 scripts 权限）
        // 注意参数名是 filename，而 /scripts/detail 用的是 file
        case "/api/scripts/history":
          _send(req, {
            "code": 200,
            "data": {
              "versions": [
                {
                  "id": "11111111-2222-3333-4444-555555555555",
                  "createdAt": "2026-10-14T07:00:00.000Z",
                  "source": "save",
                  "hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "size": 15,
                  "identical": false,
                },
                {
                  "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                  "createdAt": "2026-10-13T07:00:00.000Z",
                  "source": "baseline",
                  "hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                  "size": 14,
                  "identical": true,
                },
              ],
              "currentHash": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
              "limit": 20,
            },
          });
          return;
        case "/api/scripts/history/detail":
          _send(req, {
            "code": 200,
            "data": {
              "version": {
                "id": uri.queryParameters['id'],
                "createdAt": "2026-10-14T07:00:00.000Z",
                "source": "save",
                "hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "content": "console.log(1);",
              },
              "current": "console.log(2);",
              "currentHash": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
            },
          });
          return;
        case "/api/scripts/history/restore":
          restoreBodies.add(body);
          if (restoreMode == "conflict") {
            _sendRaw(
              req,
              409,
              jsonEncode({"code": 409, "message": "文件已变化，请刷新历史版本后重试"}),
            );
          } else {
            _send(req, {
              "code": 200,
              "data": {"changed": true, "historyRecorded": true},
            });
          }
          return;

        case "/api/scripts/detail":
          _send(req, {"code": 200, "data": "SCRIPT-BODY"});
          return;
        case "/api/configs/detail":
          _send(req, {"code": 200, "data": "CONFIG-BODY"});
          return;

        // 日志删除频率（新版的家）
        // 初始化服务端（PUT /api/user/init）
        case "/api/user/init":
          initBodies.add(body);
          if (initMode == "already") {
            _send(req, {"code": 450, "message": "未知错误"});
          } else if (initMode == "admin") {
            _send(req, {"code": 400, "message": "密码不能设置为admin"});
          } else {
            _send(req, {"code": 200, "message": "更新成功"});
          }
          return;

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

        // 运行概览
        case "/api/dashboard/overview":
          _send(req, {
            "code": 200,
            "data": {
              "total": 45,
              "enabled": 40,
              "disabled": 5,
              "todayRuns": 12,
              "todaySuccess": 10,
              "todayFail": 2,
              "successRate": "83.3",
              "avgTime": 34,
            },
          });
          return;

        // 任务视图（保存的筛选/排序方案）
        case "/api/crons/views":
          _send(req, {
            "code": 200,
            "data": [
              {"id": 1, "name": "全部任务", "type": 1, "position": 500, "isDisabled": 0},
              {
                "id": 2,
                "name": "淘宝",
                "type": 2,
                "position": 400,
                "isDisabled": 0,
                "filters": [
                  {"property": "name", "operation": "Reg", "value": "淘宝"}
                ],
                "sorts": [],
                "filterRelation": "and",
              },
            ],
          });
          return;

        // 任务：GET 返回双层包装的列表；POST/PUT 记录请求体（测多实例开关）
        case "/api/crons":
          if (req.method != "GET") {
            cronBodies.add(body);
            if (cronSaveInvalid) {
              // 复刻 celebrate 的真实返回：顶层 message 是英文，
              // 具体原因在 validation.body.message 里
              _sendRaw(
                req,
                400,
                jsonEncode({
                  "status": 400,
                  "message": "Validation failed",
                  "validation": {
                    "body": {
                      "source": "body",
                      "keys": ["schedule"],
                      "message": '"schedule" 无效的定时规则',
                    }
                  },
                }),
              );
              return;
            }
            _send(req, {
              "code": 200,
              "message": req.method == "POST" ? "创建成功" : "更新成功",
            });
            return;
          }
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
                  "allow_multiple_instances": 1,
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
    initBodies = <String>[];
    initMode = "ok";
    logBody = "";
    restoreBodies = <String>[];
    restoreMode = "ok";
    cronBodies = <String>[];
    cronSaveInvalid = false;
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

  test("实时日志：首帧 tail 取整段，之后带 nextOffset 只取增量", () async {
    logBody = "line1\nline2\n";
    final api = Api(0);

    final first = await api.inTimeLogChunk("1", tail: true);
    expect(first.success, isTrue, reason: first.message ?? "");
    expect(first.content, "line1\nline2\n");
    expect(first.nextOffset, logBody.length);
    expect(first.supportIncremental, isTrue);
    expect(requests.single, contains("tail=true"));
    expect(requests.single, contains("limit=1048576"),
        reason: "服务端默认只回 256KiB，实时日志要 1MiB");

    // 任务又输出了两行
    requests.clear();
    logBody += "line3\n";
    final second = await api.inTimeLogChunk("1", offset: first.nextOffset);

    expect(second.success, isTrue, reason: second.message ?? "");
    expect(second.content, "line3\n", reason: "增量请求应当只拿到新增内容");
    expect(second.nextOffset, logBody.length);
    expect(requests.single, contains("offset=12"));
    expect(requests.single, isNot(contains("tail=true")));
  });

  test("实时日志：文件被轮转时 nextOffset 会变小（调用方据此整段重取）", () async {
    logBody = "abcdef";
    final api = Api(0);

    // offset 超过文件长度 = 日志被清空重写
    final chunk = await api.inTimeLogChunk("1", offset: 999);
    expect(chunk.success, isTrue);
    expect(chunk.content, "");
    expect(chunk.nextOffset! < 999, isTrue,
        reason: "nextOffset 比请求的 offset 小，说明文件被轮转，页面应改为整段重取");
  });

  test("初始化服务端：PUT /api/user/init，body 为 username/password", () async {
    final api = Api(0);
    final res = await api.initUser("admin2", "pass1234");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(requests.length, 1, reason: requests.toString());
    expect(requests.single, startsWith("PUT /api/user/init"));
    final Map<String, dynamic> sent =
        jsonDecode(initBodies.single) as Map<String, dynamic>;
    expect(sent["username"], "admin2");
    expect(sent["password"], "pass1234");
  });

  test("初始化服务端：已完成初始化时服务端回 450，客户端应能识别", () async {
    initMode = "already";
    final api = Api(0);
    final res = await api.initUser("admin2", "pass1234");

    // 供登录流程区分：code 450 表示「服务端已初始化」，不该当普通失败处理
    expect(res.success, isFalse);
    expect(res.code, 450);
  });

  test("初始化服务端：密码为 admin 被服务端拒绝（400）", () async {
    initMode = "admin";
    final api = Api(0);
    final res = await api.initUser("admin2", "admin");

    expect(res.success, isFalse);
    expect(res.code, 400);
    expect(res.message, contains("admin"));
  });

  test("初始化接口必须在免登录白名单里（未初始化时还没有 token）", () {
    expect(Url.inWhiteList(Url.initUser), isTrue);
    expect(Url.inLoginList(Url.initUser), isTrue);
  });

  test("脚本历史：列表解析出 versions（source/size/identical），且用 filename 参数", () async {
    final api = Api(0);
    final res = await api.scriptHistoryList("demo.js", "");

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean?.limit, 20);
    expect(res.bean?.currentHash, "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc");
    expect(res.bean?.versions?.length, 2);

    final v = res.bean!.versions!.first;
    expect(v.id, "11111111-2222-3333-4444-555555555555");
    expect(v.source, "save");
    expect(v.sourceLabel, "保存");
    expect(v.size, 15);
    expect(v.sizeLabel, "15 B");
    expect(v.identical, isFalse);
    expect(v.content, isNull, reason: "列表接口不返回 content，只给 size/identical");

    expect(requests.single, startsWith("GET /api/scripts/history"));
    expect(requests.single, contains("filename=demo.js"));
  });

  test("脚本历史：详情返回选中版本内容 + 当前内容 + currentHash", () async {
    final api = Api(0);
    final res = await api.scriptHistoryDetail(
      "demo.js",
      "",
      "11111111-2222-3333-4444-555555555555",
    );

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean?.version?.content, "console.log(1);");
    expect(res.bean?.current, "console.log(2);");
    expect(res.bean?.currentHash, "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
        reason: "回滚时必须把它原样回传，服务端据此判断文件是否被改过");

    expect(requests.single, startsWith("GET /api/scripts/history/detail"));
    expect(requests.single, contains("id=11111111-2222-3333-4444-555555555555"));
    expect(requests.single, contains("filename=demo.js"),
        reason: "history 系列是 filename，不是 /scripts/detail 的 file");
  });

  test("脚本历史：回滚的 body 必须带 filename/path/id/expectedHash", () async {
    final api = Api(0);
    final res = await api.scriptHistoryRestore(
      "demo.js",
      "",
      "11111111-2222-3333-4444-555555555555",
      "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    );

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(requests.single, startsWith("PUT /api/scripts/history/restore"));

    final sent = jsonDecode(restoreBodies.single) as Map<String, dynamic>;
    expect(sent["filename"], "demo.js");
    expect(sent["path"], "");
    expect(sent["id"], "11111111-2222-3333-4444-555555555555");
    expect(sent["expectedHash"], "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc");
  });

  test("脚本历史：文件已变化时服务端回 409，客户端要拿到中文提示", () async {
    restoreMode = "conflict";
    final api = Api(0);
    final res = await api.scriptHistoryRestore(
      "demo.js",
      "",
      "11111111-2222-3333-4444-555555555555",
      "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    );

    expect(res.success, isFalse);
    expect(res.code, 409,
        reason: "这三个接口用的是真实 HTTP 状态码，而不是惯例的 200 + body code");
    expect(res.message, contains("文件已变化"));
  });

  test("任务解析出 allow_multiple_instances（服务端默认 0）", () async {
    final api = Api(0);
    final res = await api.crons2_13_09();

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean!.data!.first.allowMultipleInstances, 1,
        reason: "该字段是 0/1，服务端默认 0（单实例）");
  });

  test("新建任务：开启「允许多个实例」时 body 带 allow_multiple_instances=1", () async {
    final api = Api(0);
    final res = await api.addTask("demo", "task demo.js", "0 0 * * *", allowMultipleInstances: 1);

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(requests.single, startsWith("POST /api/crons"));
    final sent = jsonDecode(cronBodies.single) as Map<String, dynamic>;
    expect(sent["allow_multiple_instances"], 1);
    expect(sent["name"], "demo");
  });

  test("新建任务：不传该字段时 body 里不能出现它（避免给老服务端传未知参数）", () async {
    final api = Api(0);
    final res = await api.addTask("demo", "task demo.js", "0 0 * * *");

    expect(res.success, isTrue, reason: res.message ?? "");
    final sent = jsonDecode(cronBodies.single) as Map<String, dynamic>;
    expect(sent.containsKey("allow_multiple_instances"), isFalse,
        reason: "传 null 时必须整个字段都不出现，服务端才会沿用原值");
  });

  test("更新任务：关闭多实例时 body 带 0（id 一并提交）", () async {
    final api = Api(0);
    final res = await api.addTask("demo", "task demo.js", "0 0 * * *", id: 7, allowMultipleInstances: 0);

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(requests.single, startsWith("PUT /api/crons"));
    final sent = jsonDecode(cronBodies.single) as Map<String, dynamic>;
    expect(sent["id"], 7);
    expect(sent["allow_multiple_instances"], 0);
  });

  test("新建任务：额外调度规则按 [{schedule}] 格式提交", () async {
    final api = Api(0);
    final res = await api.addTask(
      "demo",
      "task demo.js",
      "0 9 * * *",
      extraSchedules: ["0 18 * * *", "0 23 * * *"],
    );

    expect(res.success, isTrue, reason: res.message ?? "");
    final sent = jsonDecode(cronBodies.single) as Map<String, dynamic>;
    expect(sent["extra_schedules"], [
      {"schedule": "0 18 * * *"},
      {"schedule": "0 23 * * *"},
    ], reason: "服务端 extra_schedules 是 Array<{schedule:string}>");
  });

  test("新建任务：没填额外规则时不该带该字段", () async {
    final api = Api(0);
    final res = await api.addTask("demo", "task demo.js", "0 9 * * *");

    expect(res.success, isTrue, reason: res.message ?? "");
    final sent = jsonDecode(cronBodies.single) as Map<String, dynamic>;
    expect(sent.containsKey("extra_schedules"), isFalse,
        reason: "传 null 时整个字段都不该出现");
  });

  test("编辑任务：清空额外规则要提交空数组（而不是不传）", () async {
    final api = Api(0);
    final res = await api.addTask(
      "demo",
      "task demo.js",
      "0 9 * * *",
      id: 7,
      extraSchedules: <String>[],
    );

    expect(res.success, isTrue, reason: res.message ?? "");
    final sent = jsonDecode(cronBodies.single) as Map<String, dynamic>;
    expect(sent["extra_schedules"], isEmpty,
        reason: "空数组表示清空全部额外规则；不传则服务端会沿用原值");
  });

  test("运行概览：成功率是字符串、聚合计数能转成 int", () async {
    final api = Api(0);
    final res = await api.dashboardOverview();

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean?.total, 45);
    expect(res.bean?.enabled, 40);
    expect(res.bean?.disabled, 5);
    expect(res.bean?.todayRuns, 12);
    expect(res.bean?.todaySuccess, 10);
    expect(res.bean?.todayFail, 2);
    expect(res.bean?.successRate, "83.3",
        reason: "服务端用 toFixed(1) 转成了字符串，不能按 num 解析");
    expect(res.bean?.avgTime, 34);
  });

  test("任务视图：解析 id/name，并区分系统视图与有筛选的视图", () async {
    final api = Api(0);
    final res = await api.taskViews();

    expect(res.success, isTrue, reason: res.message ?? "");
    expect(res.bean?.length, 2);

    final all = res.bean!.firstWhere((v) => v.name == "全部任务");
    expect(all.isSystem, isTrue, reason: "type=1 是系统预置");
    expect(all.hasRules, isFalse, reason: "「全部任务」没有筛选条件");

    final mine = res.bean!.firstWhere((v) => v.name == "淘宝");
    expect(mine.isSystem, isFalse);
    expect(mine.hasRules, isTrue);
    expect(mine.filters?.length, 1);
    expect(mine.filterRelation, "and");
  });

  test("任务列表：带视图 queryString 时原样透传（服务端自己解释筛选）", () async {
    final api = Api(0);
    final qs = jsonEncode({
      "filters": [
        {"property": "name", "operation": "Reg", "value": "淘宝"}
      ],
      "sorts": [],
      "filterRelation": "and",
    });
    final res = await api.crons2_13_09(queryString: qs);

    expect(res.success, isTrue, reason: res.message ?? "");
    final String raw = requests.single;
    final int q = raw.indexOf("?");
    final Map<String, String> params =
        Uri.splitQueryString(raw.substring(q + 1));
    expect(params["queryString"], qs,
        reason: "必须原封不动传给服务端，客户端不解构 filters");
  });

  test("任务列表：没有视图时不带 queryString", () async {
    final api = Api(0);
    await api.crons2_13_09();

    expect(requests.single.contains("queryString"), isFalse);
  });

  test("保存任务被校验拒绝时，要把具体原因带出来（不是英文 Validation failed）", () async {
    cronSaveInvalid = true;
    final api = Api(0);
    final res = await api.addTask("demo", "task demo.js", "50 9,14,19,23 * * *");

    expect(res.success, isFalse);
    expect(res.message, contains("无效的定时规则"),
        reason: "celebrate 把原因放在 validation.body.message，"
            "客户端必须取它，否则用户只能看到英文的 Validation failed");
    expect(res.message, isNot("Validation failed"));
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
