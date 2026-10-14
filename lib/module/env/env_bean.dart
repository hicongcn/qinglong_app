import 'package:json_conversion_annotation/json_conversion_annotation.dart';

@JsonConversion()
class EnvBean {
  String? name;
  String? value;
  String? remarks;
  int? status;
  String? sId;
  int? id;
  int? created;
  String? timestamp;
  String? updatedAt;
  String? createdAt;

  EnvBean(
      {this.value,
      this.sId,
      this.created,
      this.status,
      this.timestamp,
      this.name,
      this.remarks});

  EnvBean.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    value = json['value'];
    remarks = json['remarks'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    status = json['status'];
    id = json['id'];
    // 新版服务端主键是 int 的 id（不再有 _id）；sId 是它的字符串形式
    sId = id?.toString();
    created = int.tryParse(json['created'].toString());
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['value'] = this.value;
    data['remarks'] = this.remarks;
    data['status'] = this.status;
    data['id'] = this.id;
    data['created'] = this.created;
    data['timestamp'] = this.timestamp;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    return data;
  }

  static EnvBean jsonConversion(Map<String, dynamic> json) {
    return EnvBean.fromJson(json);
  }
}
