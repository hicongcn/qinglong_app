import 'dart:convert';

import 'package:json_conversion_annotation/json_conversion_annotation.dart';

import '../../main.dart';

@JsonConversion()
class TaskBean {
  String? name;
  String? command;
  String? schedule;
  bool? saved;
  String? sId;
  int? id;
  int? created;
  int? status;
  String? timestamp;
  int? isSystem;
  int? isDisabled;
  String? logPath;
  int? isPinned;
  int? lastExecutionTime;
  int? lastRunningTime;
  String? pid;
  String? updatedAt;
  String? createdAt;

  /// 额外调度规则（服务端 `extra_schedules`，元素形如 `{"schedule": "0 9 * * *"}`）。
  ///
  /// 一个任务除主 `schedule` 外还能挂多条规则。用来绕开"服务端 cron 校验把
  /// 等差逗号列表误判为无效、只能拆成多个任务"的场景。
  List<String>? extraSchedules;

  /// 是否允许同时运行多个实例（服务端字段 `allow_multiple_instances`，1=允许 / 0=单实例）。
  /// 服务端默认 0。**为 0 时，任务到点触发而上一次实例还在运行，服务端会先终止旧实例
  /// 再启动新的**（见 `back/shared/runCron.ts`），表现为"任务跑一会儿自己停了"。
  int? allowMultipleInstances;

  TaskBean(
      {this.name,
      this.command,
      this.schedule,
      this.saved,
      this.sId,
      this.created,
      this.status,
      this.timestamp,
      this.isSystem,
      this.isDisabled,
      this.logPath,
      this.isPinned,
      this.lastExecutionTime,
      this.lastRunningTime,
      this.pid});

  TaskBean.fromJson(Map<String, dynamic> json) {
    try {
      name = json['name'].toString();
      command = json['command'].toString();
      schedule = json['schedule'].toString();
      saved = json['saved'];
      id = json['id'];
      // 新版服务端主键是 int 的 id（不再有 _id）；sId 是它的字符串形式，
      // 供以字符串列表传参的批量接口使用。
      sId = id?.toString();
      created = int.tryParse(json['created'].toString());
      status = json['status'];
      timestamp = json['timestamp'].toString();
      createdAt = json['createdAt'];
      updatedAt = json['updatedAt'];
      isSystem = json['isSystem'];
      isDisabled = json['isDisabled'];
      logPath = json['log_path'].toString();
      isPinned = json['isPinned'];
      lastExecutionTime = int.tryParse(json['last_execution_time'].toString());
      lastRunningTime = json['last_running_time'];
      pid = json['pid'].toString();
      allowMultipleInstances = json['allow_multiple_instances'];
      if (json['extra_schedules'] is List) {
        extraSchedules = (json['extra_schedules'] as List)
            .map((e) => e is Map ? e['schedule']?.toString() : e?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e) {
      logger.e(e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['command'] = this.command;
    data['schedule'] = this.schedule;
    data['saved'] = this.saved;
    data['id'] = this.id;
    data['created'] = this.created;
    data['status'] = this.status;
    data['timestamp'] = this.timestamp;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['isSystem'] = this.isSystem;
    data['isDisabled'] = this.isDisabled;
    data['log_path'] = this.logPath;
    data['isPinned'] = this.isPinned;
    data['last_execution_time'] = this.lastExecutionTime;
    data['last_running_time'] = this.lastRunningTime;
    data['pid'] = this.pid;
    data['allow_multiple_instances'] = this.allowMultipleInstances;
    if (this.extraSchedules != null) {
      data['extra_schedules'] =
          this.extraSchedules!.map((s) => {"schedule": s}).toList();
    }
    return data;
  }

  static TaskBean jsonConversion(Map<String, dynamic> json) {
    return TaskBean.fromJson(json);
  }
}
