import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_bean.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/login/login_bean.dart';
import 'package:qinglong_app/module/login/user_bean.dart';
import 'package:qinglong_app/module/others/LogDelBean.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_bean.dart';
import 'package:qinglong_app/module/others/login_log/login_log_bean.dart';
import 'package:qinglong_app/module/others/scripts/script_history_bean.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';
import 'package:qinglong_app/module/others/update/check_update_bean.dart';
import 'package:qinglong_app/module/task/intime_log/intime_log_chunk.dart';
import 'package:qinglong_app/module/task/task_view_bean.dart';
import 'package:qinglong_app/module/login/two_factor_init_bean.dart';
import 'package:qinglong_app/module/others/dashboard/dashboard_overview_bean.dart';

import '../../module/task/TaskBean2.dart';
import '../ui/tree/models/script_data.dart';

class Api {
  int index;

  Api(this.index);

  /// 日志删除频率：2.19+ 起 /api/system/log/remove 已移除，统一走系统配置
  /// （响应结构 data.info.logRemoveFrequency）。
  Future<HttpResponse<LogDelBean>> logDel() async {
    return await getIt<Http>(instanceName: index.toString()).get<LogDelBean>(
      getIt<Url>(instanceName: index.toString()).systemConfig,
      {},
    );
  }

  Future<HttpResponse<String>> logDelTime(int time) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).logRemoveFrequency,
      {"logRemoveFrequency": time},
    );
  }

  Future<HttpResponse<SystemBean>> system() async {
    return await getIt<Http>(instanceName: index.toString()).get<SystemBean>(
      Url.system,
      {},
    );
  }

  Future<HttpResponse<LoginBean>> login(
    String userName,
    String passWord,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).post<LoginBean>(
      Url.login,
      {
        "username": userName,
        "password": passWord,
      },
    );
  }

  /// 初始化服务端（青龙首次部署时设置管理员账号密码）。
  /// 服务端已完成初始化时会返回 code 450。
  Future<HttpResponse<NullResponse>> initUser(
    String userName,
    String passWord,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      Url.initUser,
      {
        "username": userName,
        "password": passWord,
      },
    );
  }

  Future<HttpResponse<LoginBean>> loginTwo(
    String userName,
    String passWord,
    String code,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<LoginBean>(
      Url.loginTwo,
      {
        "username": userName,
        "password": passWord,
        "code": code,
      },
    );
  }

  Future<HttpResponse<LoginBean>> loginByClientId(
    String id,
    String secret,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).get<LoginBean>(
      Url.loginByClientId,
      {
        "client_id": id,
        "client_secret": secret,
      },
    );
  }

  Future<HttpResponse<UserBean>> user() async {
    return await getIt<Http>(instanceName: index.toString()).get<UserBean>(
      Url.user,
      null,
    );
  }

  /// 任务列表：新版返回 `{data:{data:[...],total}}`，由 TaskBean2 解开双层包装
  /// 运行概览（`GET /api/dashboard/overview`）。
  ///
  /// 返回今日的运行次数/成功/失败/成功率/平均耗时，以及任务总数与启用/禁用数。
  Future<HttpResponse<DashboardOverviewBean>> dashboardOverview() async {
    return await getIt<Http>(instanceName: index.toString())
        .get<DashboardOverviewBean>(
      getIt<Url>(instanceName: index.toString()).dashboardOverview,
      null,
    );
  }

  /// 任务视图列表（`GET /api/crons/views`）。
  ///
  /// 系统只预置「全部任务」一个（`type=1`，没有筛选条件）；
  /// 其余是用户在面板里自建的筛选/排序方案。
  Future<HttpResponse<List<TaskViewBean>>> taskViews() async {
    return await getIt<Http>(instanceName: index.toString())
        .get<List<TaskViewBean>>(
      getIt<Url>(instanceName: index.toString()).taskViews,
      null,
    );
  }

  /// 任务列表。
  ///
  /// [queryString] 来自任务视图：`{filters, sorts, filterRelation}` 的 JSON 串，
  /// 服务端 `crontabs()` 里 `safeJSONParse(params.queryString)` 后交给
  /// `formatViewQuery()` 解释。传 null 表示不过滤（等同「全部任务」）。
  Future<HttpResponse<TaskBean2>> crons2_13_09({String? queryString}) async {
    // 注意：服务端读取的查询参数名是 searchValue，不是 searchText
    // （传 searchText 会被忽略 → 搜索失效、永远返回全部任务）
    final Map<String, String?> query = {
      "page": "1",
      "size": "10000",
      "searchValue": "",
    };
    if (queryString != null && queryString.isNotEmpty) {
      query["queryString"] = queryString;
    }
    return await getIt<Http>(instanceName: index.toString()).get<TaskBean2>(
      getIt<Url>(instanceName: index.toString()).tasks,
      query,
    );
  }

  Future<HttpResponse<NullResponse>> deleteLogFold(String fileName, String path) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).logFoldDelete,
      {"filename": fileName, "path": path, "type": "directory"},
    );
  }

  Future<HttpResponse<NullResponse>> deleteLog(String fileName, String path) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).logFoldDelete,
      {"filename": fileName, "path": path, "type": "file"},
    );
  }

  Future<HttpResponse<String>> subscribes() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).subscribes,
      {"searchValue": ""},
    );
  }

  Future<HttpResponse<NullResponse>> updateNotifcation(Map<String, dynamic> params) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).notifcations,
      params,
    );
  }

  Future<HttpResponse<String>> getNotifcation() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).notifcations,
      {},
    );
  }

  Future<HttpResponse<String>> updateSubscribes(Map<String, dynamic> params) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).subscribes,
      params,
    );
  }

  Future<HttpResponse<String>> addSubscribes(Map<String, dynamic> params) async {
    return await getIt<Http>(instanceName: index.toString()).post<String>(
      getIt<Url>(instanceName: index.toString()).subscribes,
      params,
    );
  }

  Future<HttpResponse<NullResponse>> startTasks(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).runTasks,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> stopTasks(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).stopTasks,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> startSubscribes(List<int> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).runSubscribes,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> stopSubscribes(List<int> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).stopSubscribes,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> updatePassword(String name, String password) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      Url.updatePassword,
      {
        "username": name,
        "password": password,
      },
    );
  }

  /// 读取运行中任务的实时日志（分片）。
  ///
  /// - 首次 `tail: true`：取文件尾部（服务端默认只回 256KiB，这里要 1MiB）；
  /// - 之后带上一次返回的 `nextOffset`：**只取新增的那段**，
  ///   这样轮询可以做得很勤（1 秒）而流量极小，观感接近流式。
  Future<InTimeLogChunk> inTimeLogChunk(
    String cron, {
    int? offset,
    bool tail = false,
  }) async {
    final query = <String, String?>{"limit": _logChunkLimit};
    if (tail || offset == null) {
      query["tail"] = "true";
    } else {
      query["offset"] = offset.toString();
    }
    final envelope = await getIt<Http>(instanceName: index.toString())
        .getEnvelope(getIt<Url>(instanceName: index.toString()).intimeLog(cron), query);
    return InTimeLogChunk.fromEnvelope(envelope);
  }

  Future<HttpResponse<String>> inTimeLog(String cron) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).intimeLog(cron),
      null,
    );
  }

  Future<HttpResponse<String>> inTimeDepLog(String cron) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).intimeDepLog(cron),
      null,
    );
  }

  Future<HttpResponse<String>> inTimeSubscribeLog(int cron) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).intimeSubscribeLog(cron),
      null,
    );
  }

  /// 新增/修改任务。新版服务端主键是 number，修改时传 `id`（不再有 `_id`）。
  /// 新建 / 更新任务。
  ///
  /// [allowMultipleInstances]：1 = 允许同时运行多个实例，0 = 单实例（服务端默认）。
  /// 传 null 则**不带该字段**，服务端沿用原值 —— 老服务端不认识它，不确定时宁可不传。
  ///
  /// ⚠️ 单实例模式下（`back/shared/runCron.ts`），任务到点触发时若上一个实例还在跑，
  /// 服务端会先 `killTask` 掉它再启动新的 —— 这就是"任务自己停了"的根源。
  Future<HttpResponse<NullResponse>> addTask(
    String name,
    String command,
    String cron, {
    int? id,
    int? allowMultipleInstances,
    List<String>? extraSchedules,
  }) async {
    var data = <String, dynamic>{"name": name, "command": command, "schedule": cron};

    if (allowMultipleInstances != null) {
      data["allow_multiple_instances"] = allowMultipleInstances;
    }
    // extra_schedules 服务端是 Array<{schedule}>；传空数组表示清空全部额外规则，
    // 传 null 则完全不带该字段（服务端沿用原值）。
    if (extraSchedules != null) {
      data["extra_schedules"] =
          extraSchedules.map((s) => {"schedule": s}).toList();
    }

    if (id != null) {
      data["id"] = id;
      return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
        getIt<Url>(instanceName: index.toString()).addTask,
        data,
      );
    }
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addTask,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> delSubscribe(int cron) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addSubscribes,
      [cron],
    );
  }

  Future<HttpResponse<NullResponse>> delTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> pinTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).pinTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> unpinTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).unpinTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> enableTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).enableTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> disableTask(List<String> crons) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).disableTask,
      crons,
    );
  }

  Future<HttpResponse<NullResponse>> enableSubscribe(int id) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).enableSubscribes,
      [id],
    );
  }

  Future<HttpResponse<NullResponse>> disableSubscribe(int id) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).disableSubscribes,
      [id],
    );
  }

  Future<HttpResponse<List<ConfigBean>>> files() async {
    return await getIt<Http>(instanceName: index.toString()).get<List<ConfigBean>>(
      getIt<Url>(instanceName: index.toString()).files,
      null,
    );
  }

  /// 配置文件内容：2.19+ 起 /api/configs/<文件名> 已下线（410），改用 /api/configs/detail?path=
  Future<HttpResponse<String>> content(String name) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).configsDetail,
      {"path": name},
    );
  }

  Future<HttpResponse<NullResponse>> saveFile(String name, String content) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).saveFile,
      {"content": content, "name": name},
    );
  }

  Future<HttpResponse<List<EnvBean>>> envs(String search) async {
    return await getIt<Http>(instanceName: index.toString()).get<List<EnvBean>>(
      getIt<Url>(instanceName: index.toString()).envs,
      {"searchValue": search},
    );
  }

  Future<HttpResponse<NullResponse>> enableEnv(List<String> ids) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).enableEnvs,
      ids,
    );
  }

  /// 置顶 / 取消置顶环境变量。服务端把 body 当 number[]，Joi 会自动把
  /// 数字字符串转成数字，所以这里仍传 String 列表（与 enableEnv 一致）。
  Future<HttpResponse<NullResponse>> pinEnv(List<String> ids, bool pin) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      pin
          ? getIt<Url>(instanceName: index.toString()).envPin
          : getIt<Url>(instanceName: index.toString()).envUnpin,
      ids,
    );
  }

  Future<HttpResponse<NullResponse>> disableEnv(List<String> ids) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).disableEnvs,
      ids,
    );
  }

  Future<HttpResponse<NullResponse>> delEnvs(List<String> ids) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).delEnv,
      ids,
    );
  }

  Future<HttpResponse<NullResponse>> delEnv(String id) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).delEnv,
      [id],
    );
  }

  /// 新增/修改环境变量。新增时服务端要求请求体是**对象数组**；
  /// 修改时传 `id`（不再有 `_id`）。
  Future<HttpResponse<NullResponse>> addEnv(
    String name,
    String value,
    String remarks, {
    int? id,
  }) async {
    var data = <String, dynamic>{
      "value": value,
      "remarks": remarks,
      "name": name,
    };

    if (id != null) {
      data["id"] = id;
      return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
        getIt<Url>(instanceName: index.toString()).addEnv,
        data,
      );
    }
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addEnv,
      [data],
    );
  }

  Future<HttpResponse<NullResponse>> moveEnv(String id, int fromIndex, int toIndex) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).envMove(id),
      {"fromIndex": fromIndex, "toIndex": toIndex},
    );
  }

  Future<HttpResponse<List<LoginLogBean>>> loginLog() async {
    return await getIt<Http>(instanceName: index.toString()).get<List<LoginLogBean>>(
      getIt<Url>(instanceName: index.toString()).loginLog,
      null,
    );
  }

  Future<HttpResponse<List<TaskLogBean>>> taskLog() async {
    // 新版服务端日志列表外层固定是 data（Http.get 的默认 serializationName 即 "data"）
    return await getIt<Http>(instanceName: index.toString()).get<List<TaskLogBean>>(
      getIt<Url>(instanceName: index.toString()).taskLog,
      null,
    );
  }

  /// 单次读取日志的最大字节数（服务端上限 1MiB；不传 limit 时默认只回 256KiB 的尾部）
  static const String _logChunkLimit = "1048576";

  /// 读取日志详情：2.19+ 起 <文件名> 不再是路径段，改为查询参数 file=
  Future<HttpResponse<String>> taskLogDetail(String name, String path) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).logsDetail,
      {
        "file": name,
        "path": path,
        "limit": _logChunkLimit,
      },
    );
  }

  Future<HttpResponse<List<ScriptData>>> scripts() async {
    return await getIt<Http>(instanceName: index.toString()).get<List<ScriptData>>(
      getIt<Url>(instanceName: index.toString()).scripts,
      null,
    );
  }

  Future<HttpResponse<NullResponse>> updateScript(String name, String path, String content) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {
        "filename": name,
        "path": path,
        "content": content,
      },
    );
  }

  Future<HttpResponse<NullResponse>> delScriptFold(String fileName, String path) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {"filename": fileName, "path": path, "type": "directory"},
    );
  }

  Future<HttpResponse<NullResponse>> addScriptFolder(String fileName, String path) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {
        "directory": fileName,
        "path": path,
      },
    );
  }

  Future<HttpResponse<NullResponse>> delScriptNewVersion(String fileName, String path) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptDetail,
      {"filename": fileName, "path": path, "type": "file"},
    );
  }

  /// 脚本内容：2.19+ 起 /api/scripts/<文件名> 已下线（410），改用 /api/scripts/detail?file=&path=
  Future<HttpResponse<String>> scriptDetail(String name, String? path) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).scriptsDetail,
      {
        "file": name,
        "path": path ?? "",
      },
    );
  }

  // ── 两步验证 ──

  /// 生成两步验证密钥。已启用时会返回"请先关闭两步验证"。
  Future<HttpResponse<TwoFactorInitBean>> twoFactorInit() async {
    return await getIt<Http>(instanceName: index.toString())
        .get<TwoFactorInitBean>(
      getIt<Url>(instanceName: index.toString()).twoFactorInit,
      null,
    );
  }

  /// 用 6 位验证码激活两步验证。
  ///
  /// 服务端返回 `{code:200, data: <boolean>}`，`data` 表示验证码是否正确。
  /// 这里用 String 接（`jsonEncode(true)` → `"true"`），避免给 JsonConversion
  /// 注册 bool 类型。
  ///
  /// ⚠️ 激活成功后服务端会清空所有登录 token（`token: ''`、`tokens: {}`），
  /// 所以调用方要提示用户"需要用验证码重新登录"。
  Future<HttpResponse<String>> twoFactorActive(String code) async {
    return await getIt<Http>(instanceName: index.toString()).put<String>(
      getIt<Url>(instanceName: index.toString()).twoFactorActive,
      {"code": code},
    );
  }

  /// 关闭两步验证（服务端不需要二次确认）。
  Future<HttpResponse<NullResponse>> twoFactorDeactivate() async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).twoFactorDeactivate,
      <String, dynamic>{},
    );
  }

  /// 脚本重命名。只改文件名，不动内容；同名文件由服务端校验。
  Future<HttpResponse<NullResponse>> renameScript(
    String filename,
    String? path,
    String newFilename,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptRename,
      {
        "filename": filename,
        "path": path ?? "",
        "newFilename": newFilename,
      },
    );
  }

  // ── 脚本编辑历史（青龙 2.23+，需 scripts 权限）──
  // 服务端实现：back/shared/scriptHistory.ts
  // ⚠️ 这三个接口的参数名是 `filename`（不是 `file`）；出错时返回真实 HTTP 状态码
  //    （404 版本不存在 / 409 文件已变化 / 413 超 1 MiB 或非 UTF-8），
  //    HTTP 层会把响应体里的 message 原样带出来。

  /// 历史版本列表（按时间倒序）
  Future<HttpResponse<ScriptHistoryListBean>> scriptHistoryList(
    String filename,
    String? path,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).get<ScriptHistoryListBean>(
      getIt<Url>(instanceName: index.toString()).scriptHistory,
      {
        "filename": filename,
        "path": path ?? "",
      },
    );
  }

  /// 某个历史版本的详情（含完整内容），同时回传服务端当前内容与 currentHash
  Future<HttpResponse<ScriptHistoryDetailBean>> scriptHistoryDetail(
    String filename,
    String? path,
    String id,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).get<ScriptHistoryDetailBean>(
      getIt<Url>(instanceName: index.toString()).scriptHistoryDetail,
      {
        "filename": filename,
        "path": path ?? "",
        "id": id,
      },
    );
  }

  /// 回滚到某个历史版本。
  ///
  /// `expectedHash` 必须原样回传 detail 给出的 `currentHash`：若期间文件已被改动，
  /// 服务端返回 **409**（它会先备份当前内容再覆盖，所以不会丢东西）。
  /// 遇到 409 要重新拉详情让用户确认，**不要自动重试**。
  Future<HttpResponse<NullResponse>> scriptHistoryRestore(
    String filename,
    String? path,
    String id,
    String expectedHash,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).scriptHistoryRestore,
      {
        "filename": filename,
        "path": path ?? "",
        "id": id,
        "expectedHash": expectedHash,
      },
    );
  }

  Future<HttpResponse<List<DependencyBean>>> dependencies(String type) async {
    return await getIt<Http>(instanceName: index.toString()).get<List<DependencyBean>>(
      getIt<Url>(instanceName: index.toString()).dependencies,
      {
        "type": type.toString(),
      },
    );
  }

  /// 重新安装依赖：新版服务端主键是 number，优先用数字 id 列表。
  Future<HttpResponse<NullResponse>> dependencyReinstall(
    List<String?>? sId,
    List<int?>? id,
  ) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).dependenciesReinstall,
      (id != null && id.isNotEmpty) ? id : sId,
    );
  }

  Future<HttpResponse<String>> dependencyLog(String id) async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).dependencies + "/" + id,
      null,
    );
  }

  Future<HttpResponse<String>> addDependency(List<Map<String, dynamic>> list) async {
    return await getIt<Http>(instanceName: index.toString()).post<String>(
      getIt<Url>(instanceName: index.toString()).dependencies,
      list,
    );
  }

  Future<HttpResponse<NullResponse>> addScript(String name, String path, String content) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).addScript,
      {
        "filename": name,
        "path": path,
        "content": content,
      },
    );
  }

  /// 删除依赖。
  ///
  /// 新版服务端主键是 number，故优先使用数字 id 列表（字符串数字列表服务端也会转换）。
  /// 先走 `/dependencies/force`（连同已安装的一并卸载），失败再退回普通删除 ——
  /// 这是**运行时**回退（该端点在新版仍存在），与版本兼容无关，保留。
  Future<HttpResponse<NullResponse>> delDependency(List<String?>? sIds, List<int?>? ids) async {
    final List<dynamic>? payload = (ids != null && ids.isNotEmpty) ? ids : sIds;
    final url = getIt<Url>(instanceName: index.toString());

    var response = await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      url.dependenciesDeleteFocus,
      payload,
    );
    if (response.success == false) {
      response = await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
        url.dependencies,
        payload,
      );
    }
    return response;
  }

  Future<HttpResponse<CheckUpdateBean>> checkUpdate() async {
    return await getIt<Http>(instanceName: index.toString()).put<CheckUpdateBean>(
      getIt<Url>(instanceName: index.toString()).checkUpdate,
      {},
    );
  }

  Future<HttpResponse<String>> appKeys() async {
    return await getIt<Http>(instanceName: index.toString()).get<String>(
      getIt<Url>(instanceName: index.toString()).appkeys,
      {},
    );
  }

  Future<HttpResponse<NullResponse>> addAppKey(Map<String, dynamic> data) async {
    return await getIt<Http>(instanceName: index.toString()).post<NullResponse>(
      getIt<Url>(instanceName: index.toString()).appkeys,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> updateAppKey(Map<String, dynamic> data) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).appkeys,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> deleteAppKey(List<String> data) async {
    return await getIt<Http>(instanceName: index.toString()).delete<NullResponse>(
      getIt<Url>(instanceName: index.toString()).appkeys,
      data,
    );
  }

  Future<HttpResponse<NullResponse>> resetAppKey(dynamic id) async {
    return await getIt<Http>(instanceName: index.toString()).put<NullResponse>(
      getIt<Url>(instanceName: index.toString()).resetAppKey(id),
      {},
    );
  }
}
