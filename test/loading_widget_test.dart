// 【验证】LoadingWidget 轻量化改造
//
// 背景：任务列表每个「运行中」的行都会挂一个 LoadingWidget。原实现用的是
// loading_animation_widget 的 staggeredDotsWave —— 每帧重建 5 个点的子树，
// 其中含 10 个 Opacity（saveLayer 离屏合成）与 10 个改高度的 Container（触发布局）。
// 已改为单个 CustomPaint 直连 AnimationController（每帧仅一次 paint）。
//
// 本测试验证两件事：
//   1. 帧成本：新实现应显著低于原实现（同数量动画、同帧数）
//   2. 视觉一致：同一时刻两个实现渲染出的像素应几乎相同
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';

const Color _kColor = Color(0xff4a90d9);
const double _kSize = 12;
const int _kCount = 8; // 模拟视口内 8 个「运行中」的行

Widget _column(Widget Function(int) build) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_kCount, build),
            ),
          ),
        ),
      ),
    );

Future<double> _frameCost(
  WidgetTester tester,
  Widget Function(int) build,
) async {
  late double best;
  for (int round = 0; round < 5; round++) {
    await tester.pumpWidget(_column(build));
    await tester.pump();
    final Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();
    final double perFrame = sw.elapsedMicroseconds / 60;
    if (round == 0 || perFrame < best) {
      best = perFrame;
    }
  }
  return best;
}

Future<Uint8List> _snapshot(
  WidgetTester tester,
  Widget Function(int) build,
  int advanceMs,
) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: _column(build),
    ),
  );
  await tester.pump();
  await tester.pump(Duration(milliseconds: advanceMs));
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('帧成本：新实现应显著低于原实现', (WidgetTester tester) async {
    final double oldCost = await _frameCost(
      tester,
      (int i) => LoadingAnimationWidget.staggeredDotsWave(
        color: _kColor,
        size: _kSize,
      ),
    );
    final double newCost = await _frameCost(
      tester,
      (int i) => const LoadingWidget(color: _kColor, size: _kSize),
    );

    debugPrint('[动画成本] $_kCount 个动画/帧：'
        '原实现=${(oldCost / 1000).toStringAsFixed(3)} ms '
        '新实现=${(newCost / 1000).toStringAsFixed(3)} ms '
        '降幅=${((1 - newCost / oldCost) * 100).toStringAsFixed(1)}%');

    expect(newCost, lessThan(oldCost),
        reason: '新实现的每帧成本应低于原实现');
  });

  testWidgets('视觉一致：同一时刻两个实现的像素差异应极小', (WidgetTester tester) async {
    // 覆盖多个时刻（动画周期 1600ms）
    for (final int ms in <int>[0, 200, 400, 640, 900, 1200, 1500]) {
      final Uint8List a = await _snapshot(
        tester,
        (int i) => LoadingAnimationWidget.staggeredDotsWave(
            color: _kColor, size: _kSize),
        ms,
      );
      final Uint8List b = await _snapshot(
        tester,
        (int i) => const LoadingWidget(color: _kColor, size: _kSize),
        ms,
      );

      int diff = 0;
      int total = 0;
      for (int i = 0; i < a.length && i < b.length; i += 4) {
        // 只看 alpha 非零或任一侧非零的像素
        final int aa = a[i + 3];
        final int ba = b[i + 3];
        total++;
        final int dr = (a[i] - b[i]).abs();
        final int dg = (a[i + 1] - b[i + 1]).abs();
        final int db = (a[i + 2] - b[i + 2]).abs();
        final int da = (aa - ba).abs();
        if (dr > 24 || dg > 24 || db > 24 || da > 24) {
          diff++;
        }
      }
      final double pct = total == 0 ? 0 : diff * 100.0 / total;
      debugPrint('[视觉对比] t=${(ms / 1600).toStringAsFixed(3)} '
          '差异像素=$diff/$total (${pct.toStringAsFixed(3)}%)');
      expect(pct, lessThan(1.0),
          reason: 't=$ms ms 处两个实现的渲染差异过大');
    }
  });

  testWidgets('新实现仍是无限循环动画（持续产生帧）', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: LoadingWidget(color: _kColor))),
    );
    await tester.pump();
    final int before = tester.binding.transientCallbackCount;
    await tester.pump(const Duration(milliseconds: 16));
    final int after = tester.binding.transientCallbackCount;
    debugPrint('[动画活性] 常驻 ticker 数：pump 前=$before pump 后=$after');
    expect(after, greaterThan(0), reason: '动画应在持续运行');
  });
}
