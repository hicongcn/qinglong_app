import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';



/// 任务在排队等待空闲的并发位。
///
/// 服务端 `CrontabStatus.queued = 3`（见 `back/data/cron.ts`）—— 并发位被占满时
/// 任务不会立刻执行，而是进队列。面板里这一状态显示为「队列中」。
/// 客户端原先只认 status == 0，排队中的任务被当成「空闲」，既没标签也没动画。
///
/// 颜色用橙色，与「运行中」的主题色区分；图标复用 LoadingWidget，
/// 这样排队时也有动效，一眼能看出"在等，不是在闲"。
class QueuedWidget extends ConsumerWidget {
  const QueuedWidget({Key? key}) : super(key: key);

  /// 与「运行中」的 primaryColor 区分开
  static const Color queuedColor = Color(0xffEF9F27);

  @override
  Widget build(BuildContext context, ref) {
    return Container(
      decoration: BoxDecoration(
        color: queuedColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: queuedColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoadingWidget(
            color: queuedColor,
            size: 12,
          ),
          const SizedBox(
            width: 3,
          ),
          Text(
            "队列中",
            style: TextStyle(
              color: queuedColor,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class RunningWidget extends ConsumerWidget {
  const RunningWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    return Container(
      decoration: BoxDecoration(
        color: ref.watch(themeProvider).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: ref.watch(themeProvider).primaryColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingWidget(
            color: ref.watch(themeProvider).primaryColor,
            size: 12,
          ),
          const SizedBox(
            width: 3,
          ),
          Text(
            "运行中",
            style: TextStyle(
              color: ref.watch(themeProvider).primaryColor,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
