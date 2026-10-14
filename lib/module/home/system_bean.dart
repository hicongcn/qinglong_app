import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 服务端信息。
///
/// 本客户端**只支持新版本青龙**（服务端 2.19+ 的接口形态），因此这里不再承担
/// 「按版本切换接口」的职责 —— 原先的 `isUpperVersion*` 系列判定方法已随老接口
/// 一起移除，`version` 仅用于展示。
@JsonConversion()
class SystemBean {
  String? version;
  bool? fromAutoGet = true;

  SystemBean({
    this.version,
    this.fromAutoGet,
  });

  SystemBean.fromJson(Map<String, dynamic> json) {
    version = json['version'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['version'] = this.version;
    return data;
  }

  static SystemBean jsonConversion(Map<String, dynamic> json) {
    return SystemBean.fromJson(json);
  }
}
