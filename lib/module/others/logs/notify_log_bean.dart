import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 通知日志（`GET /api/system/notify-log`）。
///
/// 对应面板「系统设置 → 通知日志」。`status` 与面板一致：**0 成功 / 1 失败**。
@JsonConversion()
class NotifyLogBean {
  int? id;
  int? timestamp;
  String? title;
  String? content;

  /// 0 成功、1 失败
  int? status;

  /// 推送渠道（bark / serverChan / telegramBot / gotify 等）
  String? notifyType;

  /// `system` 或 `script`
  String? source;
  String? scriptName;
  String? taskId;

  NotifyLogBean({
    this.id,
    this.timestamp,
    this.title,
    this.content,
    this.status,
    this.notifyType,
    this.source,
    this.scriptName,
    this.taskId,
  });

  NotifyLogBean.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    timestamp = int.tryParse(json['timestamp'].toString());
    title = json['title'];
    content = json['content'];
    status = json['status'];
    notifyType = json['notifyType'];
    source = json['source'];
    scriptName = json['scriptName'];
    taskId = json['taskId']?.toString();
  }

  /// 是否是脚本发出的通知
  bool get fromScript => source == 'script';

  /// 来源描述：脚本通知 · xxx (#id) / 系统通知
  String get sourceText {
    final String base = fromScript ? "脚本通知" : "系统通知";
    final String name = (scriptName ?? "").isNotEmpty ? " · $scriptName" : "";
    final String task = (taskId ?? "").isNotEmpty ? " (#$taskId)" : "";
    return "$base$name$task";
  }

  bool get success => (status ?? 0) == 0;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['timestamp'] = timestamp;
    data['title'] = title;
    data['content'] = content;
    data['status'] = status;
    data['notifyType'] = notifyType;
    data['source'] = source;
    data['scriptName'] = scriptName;
    data['taskId'] = taskId;
    return data;
  }

  static NotifyLogBean jsonConversion(Map<String, dynamic> json) {
    return NotifyLogBean.fromJson(json);
  }
}
