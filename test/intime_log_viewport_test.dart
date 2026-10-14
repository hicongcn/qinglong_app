import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「运行中任务日志」的视口行为护栏。
///
/// 用户反馈过两件事：
/// 1. 没点右下角的「跟随」按钮，日志刷新时页面却自己往上跑；
/// 2. 用户正在上面翻看历史，新日志把他正在看的段落顶走了。
///
/// 两条都指向同一个不变式：**新内容只应追加在下方，视口位置不能被顶走**；
/// 只有当「跟随已开启」**且**「用户本来就停在底部」时才允许滚到底。
void main() {
  String makeLog(int from, int count) => List<String>.generate(
        count,
        (i) => "line ${from + i}  这是一行日志内容",
      ).join("\n");

  testWidgets("日志追加时视口位置不变：新内容接在下方，用户正在看的段落留在原处", (tester) async {
    final controller = ScrollController();
    String content = makeLog(0, 300);

    Widget build() => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: SizedBox(
                width: 380,
                child: ExtendedText(
                  content,
                  selectionEnabled: true,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pump();

    // 用户上滑到中间去看历史
    controller.jumpTo(400);
    await tester.pump();
    final double before = controller.offset;
    expect(before, greaterThan(0), reason: "先滚离顶部才有意义");
    expect(before, lessThan(controller.position.maxScrollExtent),
        reason: "需要停在中间（既非顶部也非底部）");

    // 模拟一次 2 秒轮询：追加 50 行新日志
    content = "$content\n${makeLog(300, 50)}";
    await tester.pumpWidget(build());
    await tester.pump();

    expect(controller.offset, before,
        reason: "内容增长只应发生在下方，视口位置不得改变");
  });

  testWidgets("跟随语义：只有「已开启 且 用户本来就在底部」才滚到底", (tester) async {
    final controller = ScrollController();

    bool isAtBottom() {
      if (!controller.hasClients) return true;
      final ScrollPosition p = controller.position;
      if (!p.hasContentDimensions) return true;
      return p.pixels >= p.maxScrollExtent - 24;
    }

    Widget build(String content) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: SizedBox(
                width: 380,
                child: ExtendedText(content, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        );

    String content = makeLog(0, 300);
    await tester.pumpWidget(build(content));
    await tester.pump();

    // 场景 A：用户滚到中间看历史。即使跟随开着，也不能把他拽走
    const bool follow = true;
    controller.jumpTo(400);
    await tester.pump();
    final double mid = controller.offset;
    final bool wasAtBottomMid = isAtBottom();
    expect(wasAtBottomMid, isFalse, reason: "停在中间时不应被判为「在底部」");
    expect(follow && wasAtBottomMid, isFalse,
        reason: "在中间 → 不跟随，这是用户「别让页面自己动」的核心诉求");
    expect(controller.offset, mid, reason: "视口不能被顶走");

    // 场景 B：用户停在底部。开了跟随就应该跟到最新
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final bool wasAtBottomEnd = isAtBottom();
    expect(wasAtBottomEnd, isTrue, reason: "停在底部应被判为「在底部」");

    content = "$content\n${makeLog(300, 50)}";
    await tester.pumpWidget(build(content));
    await tester.pump();
    if (follow && wasAtBottomEnd) {
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
    }
    expect(controller.offset, controller.position.maxScrollExtent,
        reason: "在底部 + 跟随 → 应停在最新");
  });
}
