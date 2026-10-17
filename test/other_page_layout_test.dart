import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「我的」页版式护栏。
///
/// 用户明确要求过：**只有三个板块、每行四个按钮**。之前是五张卡片
/// （多帐号 / 面板 / 工具 / 设置 / 顶行），列数从 2 到 4 混排，
/// 而且用 `Expanded(flex: 2)` 手工排，2 个条目和 4 个条目时列宽不一样。
/// 这里用源码级断言把它钉住，改版式时若破了约定会直接失败。
void main() {
  final File source =
      File('lib/module/others/other_page.dart');

  test('「我的」页只有三个板块', () {
    final String src = source.readAsStringSync();
    final Iterable<RegExpMatch> cards =
        RegExp(r'_gridCard\(\s*"([^"]+)"').allMatches(src);

    expect(cards.map((m) => m.group(1)).toList(), <String>["管理", "面板", "应用设置"]);
  });

  test('网格固定四列，不足四个用空位补齐', () {
    final String src = source.readAsStringSync();

    // 每行必须是 4 列，不能按条目数自适应
    expect(RegExp(r'for \(int i = 0; i < 4; i\+\+\)').hasMatch(src), isTrue,
        reason: "每一行都应该是 4 列");
    expect(RegExp(r'_gridRow\(').allMatches(src).length, greaterThan(0));
    // 旧的 flex 排版不允许回来
    expect(RegExp(r'Expanded\(\s*flex: 2').hasMatch(src), isFalse,
        reason: "不要再用 Expanded(flex:2) 手工排网格，列宽会不一致");
  });

  test('旧的分组名不再出现', () {
    final String src = source.readAsStringSync();
    for (final String gone in <String>["高级功能", "基础功能", "工具", "多帐号设置"]) {
      expect(RegExp('"$gone"').hasMatch(src), isFalse,
          reason: "「$gone」这个分组已经并入三个板块，不要加回来");
    }
  });
}
