import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 系统配置（`GET /api/system/config` 的响应体）。
///
/// 日志删除频率在新版服务端位于 `info.logRemoveFrequency`
/// （老接口 `/api/system/log/remove` 及其 `frequency` 字段已随版本收敛移除）。
@JsonConversion()
class LogDelBean {
  int? id;
  String? type;
  Info? info;
  String? createdAt;
  String? updatedAt;

  LogDelBean({
    this.id,
    this.type,
    this.info,
    this.createdAt,
    this.updatedAt,
  });

  LogDelBean.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    type = json['type'];
    info = json['info'] != null ? new Info.fromJson(json['info']) : null;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  /// 日志删除频率（天）
  int? get removeFrequency => info?.logRemoveFrequency;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['type'] = this.type;
    if (this.info != null) {
      data['info'] = this.info!.toJson();
    }
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    return data;
  }

  static LogDelBean jsonConversion(Map<String, dynamic> json) {
    return LogDelBean.fromJson(json);
  }
}

class Data {}

class Info {
  /// 系统配置里的日志删除频率
  int? logRemoveFrequency;

  /// 任务并发数（2.23 起从 `MaxConcurrentNum` 挪到这里，默认 max(cpus, 4)）。
  /// 核多的机器默认值偏高 → 容易 OOMKilled → 容器重启 → 任务批量中断。
  int? cronConcurrency;

  Info({this.logRemoveFrequency, this.cronConcurrency});

  Info.fromJson(Map<String, dynamic> json) {
    logRemoveFrequency = json['logRemoveFrequency'];
    cronConcurrency = json['cronConcurrency'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['logRemoveFrequency'] = this.logRemoveFrequency;
    data['cronConcurrency'] = this.cronConcurrency;
    return data;
  }
}
