import 'dart:convert';

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
    // ⚠️ 这里**全部容错**：服务端把记录存成一条 JSON，历史数据的字段类型不一定规整
    // （status 给 "0"、timestamp 给毫秒、title 偶尔是对象…），
    // 一个字段类型不符就会让 Http 的 decodeResponse 整个抛错 → 页面提示「json解析失败」。
    id = _asInt(json['id']);
    timestamp = _asInt(json['timestamp']);
    title = _asText(json['title']);
    content = _asText(json['content']);
    status = _asInt(json['status']);
    notifyType = _asText(json['notifyType']);
    source = _asText(json['source']);
    scriptName = _asText(json['scriptName']);
    taskId = _asText(json['taskId']);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is bool) return v ? 1 : 0;
    return int.tryParse(v.toString().trim());
  }

  static String? _asText(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map || v is List) return jsonEncode(v);
    return v.toString();
  }

  /// 发送时间。服务端有的版本给秒、有的给毫秒，这里按数量级判断。
  DateTime? get time {
    final int? t = timestamp;
    if (t == null || t <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(t > 100000000000 ? t : t * 1000);
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
