import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 「回到前台要不要重新拉数据」的节流闸门。
///
/// 很多「切到后台」其实是极短的系统交互：生物识别弹窗、文件选择器、分享面板、
/// 通知栏下拉、控制中心……这些往返（往往 1~2 秒）之后把任务列表（一次要
/// 10000 条）和配置文件整表重拉一遍，既无必要，又让回到前台那一下发顿。
///
/// 这里按「实际离开前台的时长」做节流：只有离开超过 [thresholdMs] 才认为
/// 数据可能过期、需要刷新；短暂离开直接跳过。
///
/// 用法：App 根节点在生命周期回调里调用 [onLifecycleState]（所有状态都传进来），
/// 各页面在 `resumed` 分支里用 [shouldRefreshOnResume] 决定是否刷新。
///
/// 注意 [shouldRefreshOnResume] 是**幂等**的：同一次「回到前台」里，
/// 多个页面向它询问会得到同一个结论（同一次进入前台只判定一次），
/// 避免出现「任务页跳过、配置页却重拉」这种自相矛盾的行为。
class AppResumeGate {
  AppResumeGate._();

  /// 离开前台超过这个时长才认为数据需要重拉。
  static const int defaultThresholdMs = 5000;

  /// 可调阈值（测试用；生产保持 [defaultThresholdMs]）。
  @visibleForTesting
  static int thresholdMs = defaultThresholdMs;

  /// 离开前台的时刻；0 表示「当前不在后台」或「还没记录过」。
  static int _leftForegroundAtMs = 0;

  /// 本次「回到前台」已经判定出的结论：null 表示还没判定过。
  static bool? _decision;

  /// 记录离开前台的时刻。非 `resumed` 一律视为离开前台。
  static void onLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return;
    }
    if (_leftForegroundAtMs == 0) {
      _leftForegroundAtMs = DateTime.now().millisecondsSinceEpoch;
    }
    // 新的「离开」开始：上一次的结论作废
    _decision = null;
  }

  /// 回到前台时询问：这次要不要刷新数据？
  ///
  /// - 确实离开超过阈值 → true；
  /// - 短暂离开 → false；
  /// - 没有记录到离开时刻（例如页面创建后从未收到过非 resumed 回调）→ true，
  ///   保守处理，宁可多刷新一次也不显示过期数据。
  static bool shouldRefreshOnResume() {
    final bool? decided = _decision;
    if (decided != null) return decided;

    bool result;
    if (_leftForegroundAtMs == 0) {
      result = true;
    } else {
      final int awayMs =
          DateTime.now().millisecondsSinceEpoch - _leftForegroundAtMs;
      result = awayMs >= thresholdMs;
    }
    _decision = result;
    return result;
  }

  @visibleForTesting
  static void reset() {
    _leftForegroundAtMs = 0;
    _decision = null;
    thresholdMs = defaultThresholdMs;
  }
}
