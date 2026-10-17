import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 运行概览（服务端 `GET /api/dashboard/overview`）。
///
/// 服务端源码 `back/api/dashboard.ts` 的返回：
/// ```json
/// { total, enabled, disabled, todayRuns, todaySuccess, todayFail,
///   successRate: "83.3",   // ← 字符串，不是数字
///   avgTime: 34 }          // 平均耗时（秒）
/// ```
@JsonConversion()
class DashboardOverviewBean {
  /// 任务总数
  int? total;

  /// 启用 / 禁用数
  int? enabled;
  int? disabled;

  /// 今日运行次数、成功、失败
  int? todayRuns;
  int? todaySuccess;
  int? todayFail;

  /// 成功率，服务端用 `toFixed(1)` 转成了字符串
  String? successRate;

  /// 平均耗时（秒）
  int? avgTime;

  DashboardOverviewBean({
    this.total,
    this.enabled,
    this.disabled,
    this.todayRuns,
    this.todaySuccess,
    this.todayFail,
    this.successRate,
    this.avgTime,
  });

  DashboardOverviewBean.fromJson(Map<String, dynamic> json) {
    total = _asInt(json['total']);
    enabled = _asInt(json['enabled']);
    disabled = _asInt(json['disabled']);
    todayRuns = _asInt(json['todayRuns']);
    todaySuccess = _asInt(json['todaySuccess']);
    todayFail = _asInt(json['todayFail']);
    successRate = json['successRate']?.toString();
    avgTime = _asInt(json['avgTime']);
  }

  /// 服务端部分计数可能是字符串（SUM 聚合返回），统一转 int
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total'] = total;
    data['enabled'] = enabled;
    data['disabled'] = disabled;
    data['todayRuns'] = todayRuns;
    data['todaySuccess'] = todaySuccess;
    data['todayFail'] = todayFail;
    data['successRate'] = successRate;
    data['avgTime'] = avgTime;
    return data;
  }

  static DashboardOverviewBean jsonConversion(Map<String, dynamic> json) {
    return DashboardOverviewBean.fromJson(json);
  }
}
