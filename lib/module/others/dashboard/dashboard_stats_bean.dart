import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 近 N 日趋势（`GET /api/dashboard/trend?days=7`）。
///
/// 服务端按天补齐（没数据的天也返回 0），`date` 形如 `2026-10-17`。
@JsonConversion()
class DashboardTrendBean {
  String? date;
  int? total;
  int? success;
  int? fail;

  DashboardTrendBean({this.date, this.total, this.success, this.fail});

  DashboardTrendBean.fromJson(Map<String, dynamic> json) {
    date = json['date']?.toString();
    total = _asInt(json['total']);
    success = _asInt(json['success']);
    fail = _asInt(json['fail']);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// 日期只留 `MM-DD`，横轴够用
  String get shortDate {
    final String d = date ?? "";
    return d.length >= 10 ? d.substring(5) : d;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['date'] = date;
    data['total'] = total;
    data['success'] = success;
    data['fail'] = fail;
    return data;
  }

  static DashboardTrendBean jsonConversion(Map<String, dynamic> json) {
    return DashboardTrendBean.fromJson(json);
  }
}

/// 今日 Top 榜（`/api/dashboard/top-time` 与 `/api/dashboard/top-count` 共用一个模型）。
///
/// - top-time：填 `avgTime` / `maxTime`（毫秒）
/// - top-count：填 `runCount`
@JsonConversion()
class DashboardTopBean {
  String? name;
  int? avgTime;
  int? maxTime;
  int? runCount;

  DashboardTopBean({this.name, this.avgTime, this.maxTime, this.runCount});

  DashboardTopBean.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    avgTime = _asInt(json['avgTime']);
    maxTime = _asInt(json['maxTime']);
    runCount = _asInt(json['runCount']);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// 毫秒 → 人话。服务端 top-time 的 `avgTime` / `maxTime` 以及 overview 的
  /// `avgTime` **都是毫秒**（面板那边也是 `/1000` 之后按秒显示的）。
  /// 直接按秒解释会得到「60794 分 3 秒」这种鬼话，所以这里统一走 [formatMs]。
  String timeText(int? ms) => formatMs(ms);

  static String formatMs(int? ms) {
    if (ms == null || ms <= 0) return "-";
    final double sec = ms / 1000.0;
    if (sec < 60) return "${sec.toStringAsFixed(1)}s";
    final int total = sec.round();
    final int m = total ~/ 60;
    final int s = total % 60;
    if (m < 60) return "$m 分 $s 秒";
    final int h = m ~/ 60;
    return "$h 小时 ${m % 60} 分";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['avgTime'] = avgTime;
    data['maxTime'] = maxTime;
    data['runCount'] = runCount;
    return data;
  }

  static DashboardTopBean jsonConversion(Map<String, dynamic> json) {
    return DashboardTopBean.fromJson(json);
  }
}

/// 面板所在主机的系统状态（`GET /api/dashboard/system`）。
@JsonConversion()
class DashboardSystemBean {
  String? platform;

  /// 进程已运行秒数
  int? uptime;

  int? cpus;

  /// 内存占用百分比，服务端 `toFixed(1)` → **字符串**
  String? memUsagePercent;

  /// Node 堆（MB）
  int? heapUsed;
  int? heapTotal;

  DashboardSystemBean({
    this.platform,
    this.uptime,
    this.cpus,
    this.memUsagePercent,
    this.heapUsed,
    this.heapTotal,
  });

  DashboardSystemBean.fromJson(Map<String, dynamic> json) {
    platform = json['platform']?.toString();
    uptime = int.tryParse(json['uptime']?.toString() ?? "");
    cpus = int.tryParse(json['cpus']?.toString() ?? "");
    memUsagePercent = json['memUsagePercent']?.toString();
    heapUsed = int.tryParse(json['heapUsed']?.toString() ?? "");
    heapTotal = int.tryParse(json['heapTotal']?.toString() ?? "");
  }

  /// 已运行时长，如「3 天 4 小时」
  String get uptimeText {
    final int s = uptime ?? 0;
    if (s <= 0) return "-";
    final int d = s ~/ 86400;
    final int h = (s % 86400) ~/ 3600;
    final int m = (s % 3600) ~/ 60;
    if (d > 0) return "$d 天 $h 小时";
    if (h > 0) return "$h 小时 $m 分";
    return "$m 分";
  }

  /// 0~1 的占用率，给进度条用
  double get memPercentValue {
    final double? v = double.tryParse(memUsagePercent ?? "");
    if (v == null) return 0;
    return (v / 100).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['platform'] = platform;
    data['uptime'] = uptime;
    data['cpus'] = cpus;
    data['memUsagePercent'] = memUsagePercent;
    data['heapUsed'] = heapUsed;
    data['heapTotal'] = heapTotal;
    return data;
  }

  static DashboardSystemBean jsonConversion(Map<String, dynamic> json) {
    return DashboardSystemBean.fromJson(json);
  }
}
