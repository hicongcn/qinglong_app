import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 任务视图（服务端 `CrontabView`，接口 `GET /api/crons/views`）。
///
/// ⚠️ 它**不是"任务分组"**，而是**保存下来的筛选 + 排序方案**：
/// 面板里可以新建视图（给个名字，配若干筛选条件），在任务页顶部切换。
/// 所以客户端这边只需要**原样透传** `filters` / `sorts` / `filterRelation`，
/// 不需要理解每个筛选条件的语义 —— 服务端 `formatViewQuery()` 会自己解释。
///
/// 字段含义（`back/data/cronView.ts`）：
/// - `type`：1 = 系统预置（只有「全部任务」），2 = 用户自建
/// - `filters`：`[{property, operation, value}]`
/// - `sorts`：`[{type: 'ASC'|'DESC', value}]`
/// - `filterRelation`：`and` / `or`
/// - `position`：倒序排序用（服务端 `order: [['position', 'DESC']]`）
@JsonConversion()
class TaskViewBean {
  int? id;
  String? name;
  int? position;
  int? isDisabled;

  /// 1 = 系统，2 = 个人
  int? type;

  /// 原样透传，不用解析内部结构
  List<dynamic>? filters;
  List<dynamic>? sorts;
  String? filterRelation;

  TaskViewBean({
    this.id,
    this.name,
    this.position,
    this.isDisabled,
    this.type,
    this.filters,
    this.sorts,
    this.filterRelation,
  });

  TaskViewBean.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    position = json['position'];
    isDisabled = json['isDisabled'];
    type = json['type'];
    filters = json['filters'] is List ? json['filters'] as List : null;
    sorts = json['sorts'] is List ? json['sorts'] as List : null;
    filterRelation = json['filterRelation'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['position'] = position;
    data['isDisabled'] = isDisabled;
    data['type'] = type;
    data['filters'] = filters;
    data['sorts'] = sorts;
    data['filterRelation'] = filterRelation;
    return data;
  }

  bool get isSystem => type == 1;

  /// 这个视图有没有实际筛选/排序条件（「全部任务」就是空的）
  bool get hasRules =>
      (filters?.isNotEmpty ?? false) || (sorts?.isNotEmpty ?? false);

  static TaskViewBean jsonConversion(Map<String, dynamic> json) {
    return TaskViewBean.fromJson(json);
  }
}
