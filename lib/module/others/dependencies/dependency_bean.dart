import 'package:json_conversion_annotation/json_conversion_annotation.dart';


@JsonConversion()
class DependencyBean {
  String? mustId;
  int? id;
  int? created;
  String? createdAt;
  int? status;
  int? type;
  String? timestamp;
  String? name;
  List<String>? log;
  String? remark;

  DependencyBean(
      {this.created,
      this.status,
      this.type,
      this.timestamp,
      this.name,
      this.log,
      this.remark});

  /// 主键的字符串形式（新版服务端主键是 int 的 id；批量接口按字符串列表传参时用）
  String? get sId => id?.toString();

  DependencyBean.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    mustId = id?.toString() ?? "";
    created = int.tryParse(json['created'].toString());
    createdAt = json['createdAt'];
    status = json['status'];
    type = json['type'];
    timestamp = json['timestamp'].toString();
    name = json['name'];
    log = json['log'].cast<String>();
    remark = json['remark'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['created'] = this.created;
    data['status'] = this.status;
    data['type'] = this.type;
    data['timestamp'] = this.timestamp;
    data['name'] = this.name;
    data['log'] = this.log;
    data['remark'] = this.remark;
    return data;
  }

  static DependencyBean jsonConversion(Map<String, dynamic> json) {
    return DependencyBean.fromJson(json);
  }
}
