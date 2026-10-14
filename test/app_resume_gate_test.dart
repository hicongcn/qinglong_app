import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/utils/app_resume_gate.dart';

/// 回前台刷新节流闸门的回归测试。
///
/// 背景：任务页一次要拉 10000 条任务、配置文件页还会顺带做备份，
/// 而「切后台」经常只是系统弹窗（生物识别 / 文件选择器 / 分享面板）造成的
/// 1~2 秒往返。闸门用来避免这类无意义的整表重拉。
void main() {
  setUp(AppResumeGate.reset);
  tearDown(AppResumeGate.reset);

  test('没有记录过离开时刻时保守放行', () {
    expect(AppResumeGate.shouldRefreshOnResume(), isTrue);
  });

  test('短暂离开后回到前台：不刷新，且多个页面结论一致', () {
    AppResumeGate.onLifecycleState(AppLifecycleState.inactive);
    AppResumeGate.onLifecycleState(AppLifecycleState.resumed);

    // 两个页面（任务页、配置文件页）同时在树上，都会来问
    expect(AppResumeGate.shouldRefreshOnResume(), isFalse);
    expect(AppResumeGate.shouldRefreshOnResume(), isFalse,
        reason: '同一次回到前台必须只有一个结论，不能一个页面跳过、另一个重拉');
  });

  test('离开较久后回到前台：需要刷新，且多个页面结论一致', () {
    AppResumeGate.thresholdMs = 0; // 模拟「离开已超过阈值」
    AppResumeGate.onLifecycleState(AppLifecycleState.paused);
    AppResumeGate.onLifecycleState(AppLifecycleState.resumed);

    expect(AppResumeGate.shouldRefreshOnResume(), isTrue);
    expect(AppResumeGate.shouldRefreshOnResume(), isTrue);
  });

  test('每次离开都会重新判定，结论不会沿用上一次', () {
    AppResumeGate.thresholdMs = 0;
    AppResumeGate.onLifecycleState(AppLifecycleState.paused);
    AppResumeGate.onLifecycleState(AppLifecycleState.resumed);
    expect(AppResumeGate.shouldRefreshOnResume(), isTrue);

    // 再来一次离开：这次阈值调大（等价于"只离开了一瞬间"）
    AppResumeGate.thresholdMs = 1000 * 1000;
    AppResumeGate.onLifecycleState(AppLifecycleState.paused);
    AppResumeGate.onLifecycleState(AppLifecycleState.resumed);
    expect(AppResumeGate.shouldRefreshOnResume(), isFalse,
        reason: '第二次离开必须重新判定，不能沿用上一次的 true');
  });

  test('重复收到非 resumed 状态不会把计时往后推', () {
    AppResumeGate.thresholdMs = 0;
    AppResumeGate.onLifecycleState(AppLifecycleState.inactive);
    AppResumeGate.onLifecycleState(AppLifecycleState.paused);
    AppResumeGate.onLifecycleState(AppLifecycleState.inactive);
    AppResumeGate.onLifecycleState(AppLifecycleState.resumed);

    expect(AppResumeGate.shouldRefreshOnResume(), isTrue);
  });
}
