import 'package:json_conversion_annotation/json_conversion_annotation.dart';



@JsonConversion()
class LogDelBean {
  int? id;
  String? type;
  Info? info;
  String? createdAt;
  String? updatedAt;
  int? frequency;

  LogDelBean({
    this.id,
    this.type,
    this.info,
    this.createdAt,
    this.updatedAt,
    this.frequency,
  });

  LogDelBean.fromJson(Map<String, dynamic> json) {
    frequency = json['frequency'];
    id = json['id'];
    type = json['type'];
    info = json['info'] != null ? new Info.fromJson(json['info']) : null;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  /// 日志删除频率（天）。
  /// 老接口 /api/system/log/remove 返回 frequency / info.frequency；
  /// 2.19+ 改读系统配置，值在 info.logRemoveFrequency。
  int? get removeFrequency =>
      info?.logRemoveFrequency ?? frequency ?? info?.frequency;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['frequency'] = this.frequency;
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
  int? frequency;

  /// 2.19+ 的字段名（系统配置里的日志删除频率）
  int? logRemoveFrequency;

  Info({this.frequency, this.logRemoveFrequency});

  Info.fromJson(Map<String, dynamic> json) {
    frequency = json['frequency'];
    logRemoveFrequency = json['logRemoveFrequency'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['frequency'] = this.frequency;
    data['logRemoveFrequency'] = this.logRemoveFrequency;
    return data;
  }
}
