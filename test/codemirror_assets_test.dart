import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 编辑器资源自包含性回归测试。
///
/// 背景：脚本编辑、配置文件、脚本新建/修改等页面都复用同一个 WebView 版
/// CodeMirror 编辑器（lib/module/code_editor/codemirror/io.dart）。
/// 旧实现把 `assets/codemirror.html` 里的 22 个 CodeMirror 资源全部指向
/// `https://unpkg.com/`，国内访问极慢甚至不可达 —— 打开编辑器要等它把
/// 20 多个文件从外网拉完，表现为长时间空白。
///
/// 现已把资源全部随 App 打包到 `assets/codemirror/`，并通过
/// `loadFlutterAsset` 以本地文件方式加载。本测试用来防止回归：
///   1) HTML 中不得再出现任何 http(s) 外链；
///   2) HTML 引用的每个本地文件都必须真实存在且非空；
///   3) 应用用到的全部语言模式与主题都必须已打包；
///   4) pubspec.yaml 必须声明该资源目录（否则资源不会进包）。
void main() {
  final Directory assetsDir = Directory('assets/codemirror');
  final File htmlFile = File('assets/codemirror/index.html');

  /// 应用里实际会请求到的语言模式（见各编辑页的 getLanguageType）
  const List<String> requiredModes = <String>[
    'shell',
    'javascript',
    'python',
    'yaml',
  ];

  /// CodeMirrorOptions 只会取这两个主题（深色 3024-night / 浅色 neat）
  const List<String> requiredThemes = <String>[
    'neat',
    '3024-night',
  ];

  test('编辑器目录与页面存在', () {
    expect(assetsDir.existsSync(), isTrue,
        reason: 'assets/codemirror 目录缺失，编辑器资源没有随包');
    expect(htmlFile.existsSync(), isTrue,
        reason: 'assets/codemirror/index.html 缺失');
  });

  test('页面不再引用任何外网资源（这是"加载很慢"的根因）', () {
    final String html = htmlFile.readAsStringSync();

    // 允许出现在注释里的说明文字，但绝不允许出现在 href/src 里
    final Iterable<RegExpMatch> externalRefs = RegExp(
      r'''(?:src|href)\s*=\s*["'](https?:)?//''',
      caseSensitive: false,
    ).allMatches(html);

    expect(
      externalRefs,
      isEmpty,
      reason: 'index.html 仍存在外链引用：'
          '${externalRefs.map((m) => m.group(0)).toList()}',
    );
  });

  test('页面引用的每个本地资源都存在且非空', () {
    final String html = htmlFile.readAsStringSync();
    final Iterable<RegExpMatch> refs = RegExp(
      r'''(?:src|href)\s*=\s*["']([^"'#?]+)["']''',
      caseSensitive: false,
    ).allMatches(html);

    final List<String> checked = <String>[];
    for (final RegExpMatch m in refs) {
      final String ref = m.group(1)!.trim();
      if (ref.isEmpty || ref.startsWith('data:')) continue;
      checked.add(ref);
      final File f = File('assets/codemirror/$ref');
      expect(f.existsSync(), isTrue, reason: 'index.html 引用的 $ref 不存在');
      expect(f.lengthSync(), greaterThan(100),
          reason: '$ref 体积异常，可能下载不完整');
    }
    expect(checked, isNotEmpty, reason: 'index.html 里没有解析到任何本地引用');
  });

  test('应用会用到的语言模式与主题都已打包', () {
    for (final String mode in requiredModes) {
      final File f = File('assets/codemirror/mode-$mode.js');
      expect(f.existsSync(), isTrue, reason: '缺少语言模式资源 mode-$mode.js');
      expect(f.lengthSync(), greaterThan(100));
    }
    for (final String theme in requiredThemes) {
      final File f = File('assets/codemirror/theme-$theme.css');
      expect(f.existsSync(), isTrue, reason: '缺少主题资源 theme-$theme.css');
      expect(f.lengthSync(), greaterThan(100));
    }
  });

  test('CodeMirror 核心与折叠/搜索插件齐全', () {
    const List<String> core = <String>[
      'codemirror.js',
      'codemirror.css',
      'addon-search.js',
      'addon-dialog.js',
      'addon-searchcursor.js',
      'addon-match-highlighter.js',
      'addon-jump-to-line.js',
      'addon-foldcode.js',
      'addon-foldgutter.js',
      'addon-brace-fold.js',
      'addon-xml-fold.js',
      'addon-markdown-fold.js',
      'addon-comment-fold.js',
      'addon-indent-fold.js',
      'addon-dialog.css',
      'addon-foldgutter.css',
    ];
    for (final String name in core) {
      final File f = File('assets/codemirror/$name');
      expect(f.existsSync(), isTrue, reason: '缺少 $name');
    }
    // 核心库应有实质体积（防止只提交了占位文件）
    expect(File('assets/codemirror/codemirror.js').lengthSync(),
        greaterThan(50 * 1024),
        reason: 'codemirror.js 体积过小，可能不是完整库');
  });

  test('行号栏必须禁止选中（否则复制代码会带上行号）', () {
    final String html = File('assets/codemirror/index.html').readAsStringSync();
    expect(
      html.contains('user-select: none'),
      isTrue,
      reason: 'index.html 缺少 gutter 的 user-select: none —— '
          'CodeMirror 只把 gutter 选区背景设为透明，文字仍在选区里，'
          '移动端全选/拖选会把行号一起复制出来',
    );
    // 至少要覆盖行号栏与折叠加槽
    expect(html.contains('.CodeMirror-linenumber'), isTrue,
        reason: '未针对 .CodeMirror-linenumber 关闭选中');
  });

  test('pubspec.yaml 已声明编辑器资源目录', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('assets/codemirror/'),
      isTrue,
      reason: 'pubspec.yaml 未声明 assets/codemirror/，资源不会被打进安装包',
    );
    expect(
      pubspec.contains('assets/codemirror.html'),
      isFalse,
      reason: 'pubspec.yaml 仍引用已删除的 assets/codemirror.html',
    );
  });
}
