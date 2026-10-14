// 【回归测试】首页懒加载 IndexedStack
//
// 背景：首页 4 个 tab 原来在启动时就全部构建（各自发首屏请求），改为「访问过才构建」。
// 首次实现踩过一个坑：未访问的 tab 用了裸 `SizedBox.shrink()` 占位 ——
// IndexedStack 是 Stack 子类且默认 StackFit.loose，而 RenderStack 的规则是
// 「存在非定位 child 时尺寸由这些 child 决定」，于是整个 body 塌成 0×0，
// 真机上表现为**打开 App 一片空白**。
//
// 本测试守住两件事：
//   1. 未访问的 tab 不构建（省启动时间与内存）
//   2. 整体尺寸必须撑满父级（不得塌陷）—— 这是白屏回归的护栏

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/ui/lazy_indexed_stack.dart';

void main() {
  testWidgets("只构建首屏 tab；切换后才构建目标 tab", (tester) async {
    final built = <int>[];
    List<Widget> pages() => List<Widget>.generate(
          4,
          (i) => Builder(
            key: ValueKey('page-$i'),
            builder: (_) {
              built.add(i);
              return ColoredBox(color: Colors.white, child: Text('page $i'));
            },
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazyIndexedStack(index: 0, children: pages()),
        ),
      ),
    );

    expect(built, [0], reason: "启动时只应构建首屏");
    expect(find.text('page 0'), findsOneWidget);
    expect(find.text('page 2'), findsNothing, reason: "未访问的 tab 不应出现在树里");

    // 切到 tab 2
    built.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazyIndexedStack(index: 2, children: pages()),
        ),
      ),
    );

    expect(built.contains(2), isTrue, reason: "切过去的 tab 必须构建");
    expect(find.text('page 2'), findsOneWidget);
  });

  testWidgets("initialIndexes 指定的多个 tab 在启动时就构建（任务/环境变量/配置文件）", (tester) async {
    final built = <int>[];
    List<Widget> pages() => List<Widget>.generate(
          4,
          (i) => Builder(
            key: ValueKey('page-$i'),
            builder: (_) {
              built.add(i);
              return ColoredBox(color: Colors.white, child: Text('page $i'));
            },
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazyIndexedStack(
            index: 0,
            initialIndexes: const <int>{0, 1, 2},
            children: pages(),
          ),
        ),
      ),
    );

    expect(built.toSet().containsAll(<int>{0, 1, 2}), isTrue,
        reason: "首页要求任务/环境变量/配置文件在开 App 时同步加载（各自发起首屏请求）");
    expect(built.contains(3), isFalse, reason: "「我的」仍应按需构建");
  });

  testWidgets("尺寸不得塌陷：body 必须撑满可用高度（白屏回归护栏）", (tester) async {
    const double kHeight = 600;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: kHeight,
            child: LazyIndexedStack(
              index: 0,
              children: const [
                ColoredBox(color: Colors.white),
                ColoredBox(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );

    final stackSize = tester.getSize(find.byType(IndexedStack));
    expect(
      stackSize.height,
      kHeight,
      reason: "IndexedStack 必须撑满父级；为 0 说明占位写成了非定位 child（会白屏）",
    );
    expect(stackSize.width, greaterThan(0));
  });
}
