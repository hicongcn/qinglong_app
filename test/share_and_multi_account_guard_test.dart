import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 分享 / 多账号渲染的回归护栏。
///
/// 两个都出过线上问题：
///  1. 日志页、配置文件页直接用裸 `Share.share(content ?? "")` —— 既没有空内容保护，
///     也没给 iPad 必需的 `sharePositionOrigin`，表现就是「点分享没反应」。
///     现在统一走 `utils/extension.dart` 的 `shareTextContent`。
///  2. 多账号切换页直接 `getIt<UserInfoViewModel>(instanceName: index)` ——
///     该实例由对应账号页的 initState 注册，没打开过的账号取不到会抛异常，整页崩。
///     现在改为从 TokenBean 渲染 + `tryUserInfo` 降级。
void main() {
  test('分享必须走 shareTextContent（裸 Share.share 会让 iPad 上无反应）', () {
    final List<String> offenders = <String>[];
    for (final File f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('utils/extension.dart')) continue; // 工具方法本身
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        if (!line.contains('Share.share(')) continue;
        if (line.trimLeft().startsWith('//')) continue;
        // 允许显式传了 sharePositionOrigin 的写法（后面几行里出现即可）
        final String window = lines
            .skip(i)
            .take(6)
            .join('\n');
        if (!window.contains('sharePositionOrigin')) {
          offenders.add("${f.path}:${i + 1}");
        }
      }
    }
    expect(offenders, isEmpty,
        reason: "这些地方直接调了 Share.share 且没给 sharePositionOrigin，iPad 上点分享不会弹面板：$offenders");
  });

  test('多账号列表不得直接 getIt<UserInfoViewModel>(instanceName: index)', () {
    final File f = File('lib/module/others/change_account_page.dart');
    final String src = f.readAsStringSync();

    // tryUserInfo() 内部本来就要调 getIt（外面包了 try/catch），把它剥掉再检查
    String outside = src;
    final int helper = src.indexOf('UserInfoViewModel? tryUserInfo(');
    if (helper >= 0) {
      final int end = src.indexOf('\n  }', helper);
      outside = src.substring(0, helper) + src.substring(end);
    }

    expect(
      RegExp(r'getIt<UserInfoViewModel>\(instanceName: index\.toString\(\)\)')
          .hasMatch(outside),
      isFalse,
      reason: "没打开过的账号没有注册 UserInfoViewModel 实例，直接取会抛异常并把整页顶成错误页；"
          "请用 tryUserInfo() 或 TokenBean 渲染",
    );
    expect(src.contains('tryUserInfo('), isTrue,
        reason: "应保留 tryUserInfo 的降级路径");
    expect(RegExp(r'ValueKey\("?\$\{host\}_\$index').hasMatch(src), isTrue,
        reason: "Slidable 的 key 必须带 index，否则两个同 host 账号会因重复 key 崩");
  });
}
