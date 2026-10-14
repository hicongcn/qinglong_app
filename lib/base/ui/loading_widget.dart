import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 轻量加载动画：5 个错落起伏的点。
///
/// 视觉与原先使用的 `LoadingAnimationWidget.staggeredDotsWave` 保持一致
/// （同样的 5 个点、同样的相位区间、同样的尺寸与圆角），但绘制方式改为
/// **单个 CustomPaint 直连 AnimationController**。
///
/// 原实现的代价（已核实包源码）：每个点在每帧都重建一次 widget 子树，其中包含
/// 2 个 `Opacity`（每个都触发 `saveLayer` 离屏合成）与 2 个改高度的
/// `Container`（每个都触发父级重新布局）。即一个 LoadingWidget 每帧要付出
/// 5 次子树重建 + 10 次 saveLayer + 10 次布局。
/// 而它在任务列表中每个「运行中」的行都会挂一个，滚动时叠加即成为掉帧主因。
///
/// 本实现每帧只有一次 `paint`：无 widget 重建、无布局、无 saveLayer。
/// 阶段切换原本就是硬切换（原实现用的是 `Opacity(0/1)`，不是渐隐），
/// 故改为「满足条件才绘制」在视觉上完全等价。
class LoadingWidget extends StatefulWidget {
  final Color color;
  final double size;

  const LoadingWidget({
    Key? key,
    this.color = const Color(0xffc8c9cc),
    this.size = 30,
  }) : super(key: key);

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _StaggeredDotsWavePainter(
            controller: _controller,
            color: widget.color,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

/// 单个点的两个阶段（上升 / 回落）的相位区间。
class _DotSpec {
  const _DotSpec({
    required this.heightInterval,
    required this.offsetInterval,
    required this.reverseHeightInterval,
    required this.reverseOffsetInterval,
    required this.tall,
  });

  final Interval heightInterval;
  final Interval offsetInterval;
  final Interval reverseHeightInterval;
  final Interval reverseOffsetInterval;

  /// 原包中 oddDotHeight = size*0.4、evenDotHeight = size*0.7；
  /// 此处 true 表示用较大的 0.7×size。
  final bool tall;
}

/// 与原 `staggeredDotsWave` 完全一致的 5 个点参数。
const List<_DotSpec> _kDots = <_DotSpec>[
  _DotSpec(
    heightInterval: Interval(0.0, 0.1),
    offsetInterval: Interval(0.18, 0.28),
    reverseHeightInterval: Interval(0.28, 0.38),
    reverseOffsetInterval: Interval(0.47, 0.57),
    tall: false,
  ),
  _DotSpec(
    heightInterval: Interval(0.09, 0.19),
    offsetInterval: Interval(0.27, 0.37),
    reverseHeightInterval: Interval(0.37, 0.47),
    reverseOffsetInterval: Interval(0.56, 0.66),
    tall: true,
  ),
  _DotSpec(
    heightInterval: Interval(0.18, 0.28),
    offsetInterval: Interval(0.36, 0.46),
    reverseHeightInterval: Interval(0.46, 0.56),
    reverseOffsetInterval: Interval(0.65, 0.75),
    tall: false,
  ),
  _DotSpec(
    heightInterval: Interval(0.27, 0.37),
    offsetInterval: Interval(0.45, 0.55),
    reverseHeightInterval: Interval(0.55, 0.65),
    reverseOffsetInterval: Interval(0.74, 0.84),
    tall: true,
  ),
  _DotSpec(
    heightInterval: Interval(0.36, 0.46),
    offsetInterval: Interval(0.54, 0.64),
    reverseHeightInterval: Interval(0.64, 0.74),
    reverseOffsetInterval: Interval(0.83, 0.93),
    tall: false,
  ),
];

class _StaggeredDotsWavePainter extends CustomPainter {
  _StaggeredDotsWavePainter({
    required this.controller,
    required this.color,
    required this.size,
  }) : super(repaint: controller);

  final AnimationController controller;
  final Color color;
  final double size;

  static double _lerp(double a, double b, double u) => a + (b - a) * u;

  /// 与 `Interval`（linear curve）等价：区间外 clamp 到 0 / 1。
  static double _progress(double t, Interval interval) {
    final double duration = interval.end - interval.begin;
    if (duration <= 0) {
      return t >= interval.end ? 1 : 0;
    }
    final double u = (t - interval.begin) / duration;
    return u < 0 ? 0 : (u > 1 ? 1 : u);
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final double t = controller.value;
    final double s = size;
    final double dotWidth = s * 0.13;
    final double maxDy = -(s * 0.20);
    final double centerY = s / 2;
    // 原实现用 Row(mainAxisAlignment: spaceBetween) 排 5 个宽 dotWidth 的点，
    // 故首尾点的中心间距恰为 size - dotWidth。
    final double span = s - dotWidth;
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = color;

    for (int i = 0; i < _kDots.length; i++) {
      final _DotSpec dot = _kDots[i];
      final double maxHeight = dot.tall ? s * 0.7 : s * 0.4;
      final double cx = dotWidth / 2 + span * i / (_kDots.length - 1);

      // 阶段 A（上升）：t <= offset.end 时可见
      if (t <= dot.offsetInterval.end) {
        final double h =
            _lerp(dotWidth, maxHeight, _progress(t, dot.heightInterval));
        final double dy = _lerp(0, maxDy, _progress(t, dot.offsetInterval));
        _drawDot(canvas, cx, centerY + dy, dotWidth, h, paint);
      }
      // 阶段 B（回落）：t >= offset.end 时可见（与原实现的硬切换一致）
      if (t >= dot.offsetInterval.end) {
        final double h = _lerp(
            maxHeight, dotWidth, _progress(t, dot.reverseHeightInterval));
        final double dy =
            _lerp(maxDy, 0, _progress(t, dot.reverseOffsetInterval));
        _drawDot(canvas, cx, centerY + dy, dotWidth, h, paint);
      }
    }
  }

  void _drawDot(
    Canvas canvas,
    double cx,
    double cy,
    double width,
    double height,
    Paint paint,
  ) {
    if (height <= 0) {
      return;
    }
    final Rect rect =
        Rect.fromCenter(center: Offset(cx, cy), width: width, height: height);
    // 原实现用 BorderRadius.circular(size)，实际被尺寸裁剪为完全圆头。
    final double radius = math.min(width, height) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StaggeredDotsWavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.size != size;
}
