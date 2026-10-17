// 源码级护栏：这些能力是"面板已经有、客户端曾经缺"的部分，靠文本断言防回归。
//
// 设计取舍：这三项本质上是"UI 有没有接上服务端已有的字段/状态"，用 widget 测试
// 需要构造整套 provider / getIt，成本远高于收益。项目里既有的
// no_vip_gating_test.dart 用的也是同样思路，保持一致。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('应用权限与服务端一致（subscriptions / dashboard 曾被漏掉）', () {
    // 服务端权威取值：src/utils/config.ts 的 scopes，共 9 项
    const List<String> allScopes = <String>[
      'crons',
      'envs',
      'subscriptions',
      'configs',
      'scripts',
      'logs',
      'dependencies',
      'system',
      'dashboard',
    ];

    final String vm =
        File('lib/module/appkey/appkey_viewmodel.dart').readAsStringSync();
    for (final String key in allScopes) {
      expect(
        vm.contains('"$key"'),
        isTrue,
        reason: '权限映射缺少 "$key"（getScopeNames / getScopeKeys 必须覆盖全部 9 项）',
      );
    }

    final String ui =
        File('lib/module/appkey/add_appkey_page.dart').readAsStringSync();
    expect(ui.contains('订阅管理'), isTrue, reason: '权限勾选列表缺少「订阅管理」');
    expect(ui.contains('仪表盘'), isTrue, reason: '权限勾选列表缺少「仪表盘」');
  });

  test('任务「队列中」状态有提示（服务端 CrontabStatus.queued = 3）', () {
    final String widget =
        File('lib/base/ui/running_widget.dart').readAsStringSync();
    expect(
      widget.contains('class QueuedWidget'),
      isTrue,
      reason: '缺少 QueuedWidget —— 排队中的任务会显示成「空闲」，既没标签也没动效',
    );

    final String page = File('lib/module/task/task_page.dart').readAsStringSync();
    expect(page.contains('status == 3'), isTrue,
        reason: '任务列表未处理 queued 状态');
    expect(page.contains('QueuedWidget'), isTrue,
        reason: '任务列表未使用 QueuedWidget');

    final String detail =
        File('lib/module/task/task_detail/task_detail_page.dart').readAsStringSync();
    expect(detail.contains('队列中'), isTrue, reason: '任务详情页未显示排队中');
  });

  test('环境变量支持置顶（服务端 isPinned / envs/pin）', () {
    final String bean = File('lib/module/env/env_bean.dart').readAsStringSync();
    expect(bean.contains('isPinned'), isTrue, reason: 'EnvBean 缺 isPinned 字段');
    expect(bean.contains("json['isPinned']"), isTrue, reason: '未解析 isPinned');

    final String page = File('lib/module/env/env_page.dart').readAsStringSync();
    expect(page.contains('pinEnv(context)'), isTrue,
        reason: '环境变量侧滑菜单没有置顶入口');
    expect(page.contains('push_pin'), isTrue, reason: '置顶图标缺失');

    final String api = File('lib/base/http/api.dart').readAsStringSync();
    expect(api.contains('envPin'), isTrue, reason: '接口未接 envs/pin');
  });

  test('任务详情页有「运行 / 停止」入口（startCron/stopCron 不能是死代码）', () {
    final String page =
        File('lib/module/task/task_detail/task_detail_page.dart').readAsStringSync();
    expect(page.contains('startCron'), isTrue);
    expect(page.contains('stopCron'), isTrue);
    // 方法早就写好了，但曾经没挂到菜单上 —— 用调用点断言，防止再退回去
    expect(page.contains('startCron(context, ref)'), isTrue,
        reason: 'startCron 只有定义、没有调用点，等于没有入口');
    expect(page.contains('stopCron(context, ref)'), isTrue,
        reason: 'stopCron 只有定义、没有调用点，等于没有入口');
  });

  test('任务编辑支持额外调度规则（服务端 extra_schedules）', () {
    final String bean = File('lib/module/task/task_bean.dart').readAsStringSync();
    expect(bean.contains('extraSchedules'), isTrue);
    expect(bean.contains("json['extra_schedules']"), isTrue,
        reason: 'TaskBean 未解析 extra_schedules');

    final String page =
        File('lib/module/task/add_task_page.dart').readAsStringSync();
    expect(page.contains('额外调度规则'), isTrue, reason: '编辑页缺少额外规则入口');
    expect(page.contains('extraSchedules'), isTrue, reason: '编辑页未提交 extra_schedules');

    final String api = File('lib/base/http/api.dart').readAsStringSync();
    expect(api.contains('"extra_schedules"'), isTrue,
        reason: 'addTask 未带上 extra_schedules');
  });
}
