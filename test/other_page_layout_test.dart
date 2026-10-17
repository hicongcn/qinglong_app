import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「我的」页版式护栏。
///
/// 用户明确要求：
///  - 板块只有两个：**青龙设置**（面板/服务端功能）与 **App 设置**（这台手机上的功能），
///    功能**不许混**；条目顺序与命名尽量对齐青龙面板的左侧菜单。
///  - 每行四个按钮，列宽恒定。
///
/// 踩过的坑：按"重要性"分组把归属搞错（多账号数进青龙、扫描依赖进应用设置），
/// 已被用户逐一纠正。这里用源码断言钉死，改错就红。
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

  test('板块只有两个：青龙设置 与 App 设置', () {
    final String src = source.readAsStringSync();
    final List<String> cards = RegExp(r'_gridCard\(\s*"([^"]+)"')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toList();
    expect(cards, <String>["青龙设置", "App 设置"]);
  });

  test('青龙设置：顺序对齐面板菜单（仪表盘→订阅→脚本→依赖→日志→系统设置）', () {
    final String src = source.readAsStringSync();
    expect(
      cellsOf(src, "青龙设置"),
      <String>[
        "运行概览",
        "订阅管理",
        "脚本管理",
        "依赖管理",
        "任务日志",
        "登录日志",
        "系统日志",
        "通知日志",
        "通知设置",
        "应用密钥",
        "两步验证",
        "面板设置",
      ],
    );
  });

  test('App 设置：只放客户端功能，扫描依赖在 App 侧', () {
    final String src = source.readAsStringSync();
    expect(
      cellsOf(src, "App 设置"),
      <String>[
        "扫描依赖",
        "多账号数",
        "账号排序",
        "字体大小",
        "文件备份",
        "系统设置",
        "关于软件",
      ],
    );
  });

  test('青龙 12 个（三行）、App 7 个，每行四列', () {
    final String src = source.readAsStringSync();
    expect(cellsOf(src, "青龙设置").length, 12);
    expect(cellsOf(src, "App 设置").length, 7);
    expect(RegExp(r'for \(int i = 0; i < 4; i\+\+\)').hasMatch(src), isTrue);
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
      "日志设置",
    ]) {
      expect(RegExp('"$gone').hasMatch(src), isFalse,
          reason: "「$gone」这个分组/条目名已经废弃（日志设置已并入面板设置页），不要加回来");
    }
  });

  /// 「字体大小」只认 MediaQuery.textScaleFactor，而 `RichText` **不会**自动乘这个系数 ——
  /// 环境变量的「名称 / 备注」当初就是因为用了 RichText，调字体大小毫无反应。
  /// 这个断言扫全仓，防止再退回裸 RichText。
  test('所有 RichText 都显式带上 textScaleFactor', () {
    final List<File> files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    final List<String> offenders = <String>[];
    for (final File f in files) {
      final String src = f.readAsStringSync();
      int index = src.indexOf('RichText(');
      while (index >= 0) {
        final String after =
            src.substring(index, (index + 240).clamp(0, src.length));
        if (!after.contains('textScaleFactor')) {
          final int line = '\n'.allMatches(src.substring(0, index)).length + 1;
          offenders.add("${f.path}:$line");
        }
        index = src.indexOf('RichText(', index + 9);
      }
    }

    expect(offenders, isEmpty,
        reason: "这些 RichText 没带 textScaleFactor，字体大小设置对它们不生效：$offenders");
  });
}
