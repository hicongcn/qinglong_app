import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「我的」页版式护栏。
///
/// 用户明确要求：
///  - 只有两个板块，**按功能归属划分**：`青龙` = 面板（服务端）的能力，
///    `App 设置` = 这台手机上的能力；两个板块的功能**不许混**。
///  - 每行四个按钮，列宽恒定。
///
/// 之前踩过的坑：按"重要性"分组，把 `多账号数/账号排序`（App）塞进「管理」、
/// 把 `扫描依赖/日志设置`（青龙）塞进「应用设置」，被用户指出来。这里用源码断言钉死。
void main() {
  final File source = File('lib/module/others/other_page.dart');

  /// 取出 `_gridCard("标题", <Widget>[ ... ])` 里的条目名
  List<String> cellsOf(String src, String title) {
    final int start = src.indexOf('_gridCard("$title"');
    expect(start, greaterThanOrEqualTo(0), reason: "找不到板块「$title」");
    final int end = src.indexOf(']),', start);
    expect(end, greaterThan(start));
    return RegExp(r'_cell\("([^"]+)"')
        .allMatches(src.substring(start, end))
        .map((m) => m.group(1)!)
        .toList();
  }

  test('板块只有两个：青龙 与 App 设置', () {
    final String src = source.readAsStringSync();
    final List<String> cards = RegExp(r'_gridCard\(\s*"([^"]+)"')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toList();
    expect(cards, <String>["青龙", "App 设置"]);
  });

  test('青龙板块只放服务端功能', () {
    final String src = source.readAsStringSync();
    expect(
      cellsOf(src, "青龙"),
      <String>[
        "订阅管理",
        "脚本管理",
        "运行概览",
        "两步验证",
        "任务日志",
        "登录日志",
        "扫描依赖",
        "日志设置",
      ],
    );
  });

  test('App 设置板块只放客户端功能', () {
    final String src = source.readAsStringSync();
    expect(
      cellsOf(src, "App 设置"),
      <String>[
        "应用密钥",
        "通知设置",
        "多账号数",
        "账号排序",
        "字体大小",
        "文件备份",
        "系统设置",
        "关于软件",
      ],
    );
  });

  test('两个板块各 8 个，正好两行四列', () {
    final String src = source.readAsStringSync();
    expect(cellsOf(src, "青龙").length, 8);
    expect(cellsOf(src, "App 设置").length, 8);
    // 每行必须是 4 列，不能按条目数自适应
    expect(RegExp(r'for \(int i = 0; i < 4; i\+\+\)').hasMatch(src), isTrue);
    // 旧的 flex 排版不允许回来
    expect(RegExp(r'Expanded\(\s*flex: 2').hasMatch(src), isFalse,
        reason: "不要再用 Expanded(flex:2) 手工排网格，列宽会不一致");
  });

  test('旧分组名不再出现', () {
    final String src = source.readAsStringSync();
    for (final String gone in <String>[
      "高级功能",
      "基础功能",
      "工具",
      "多帐号设置",
      "面板\"",
      "应用设置",
    ]) {
      expect(RegExp('"$gone').hasMatch(src), isFalse,
          reason: "「$gone」这个分组/条目名已经废弃，不要加回来");
    }
  });
}
