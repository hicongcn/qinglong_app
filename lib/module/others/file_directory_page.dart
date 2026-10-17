import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../base/theme.dart';
import 'scripts/script_code_detail_page.dart';

class FileDirectoryPage extends ConsumerStatefulWidget {
  final String path;

  const FileDirectoryPage({
    Key? key,
    required this.path,
  }) : super(key: key);

  @override
  ConsumerState<FileDirectoryPage> createState() => _FileDirectoryPageState();
}

class _FileDirectoryPageState extends ConsumerState<FileDirectoryPage> {
  List<String> paths = [];

  @override
  void initState() {
    super.initState();
    readFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        title: "查看文件",
      ),
      body: ListView.separated(
        itemBuilder: (context, index) {
          bool isDirectly = Directory(paths[index]).existsSync();

          return ListTile(
            onTap: () async {
              if (isDirectly) {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => FileDirectoryPage(
                      path: paths[index],
                    ),
                  ),
                );
              } else {
                try {
                  String content = await File(paths[index]).readAsString();
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => ScriptCodeDetailPage(
                        title: paths[index].replaceAll(widget.path, "").replaceAll("/", ""),
                        content: content,
                        absPath: paths[index],
                        canRestore: true,
                      ),
                    ),
                  );
                } catch (e) {
                  e.toString().toast();
                }
              }
            },
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 15,
            ),
            trailing: !isDirectly
                ? const SizedBox.shrink()
                : Icon(
                    CupertinoIcons.right_chevron,
                    size: 16,
                    color: ref.watch(themeProvider).themeColor.descColor(),
                  ),
            title: Text(
              paths[index].replaceAll(widget.path, "").replaceAll("/", ""),
            ),
            subtitle: isDirectly
                ? null
                : _fileHint(_baseName(paths[index])),
          );
        },
        itemCount: paths.length,
        separatorBuilder: (context, index) {
          return const Divider(
            indent: 15,
            height: 1,
          );
        },
      ),
    );
  }

  /// 读目录内容并排序。
  ///
  /// `Directory.list()` 返回的是**文件系统枚举顺序**，没有任何保证 —— 备份文件
  /// （名字是 `HH-mm-ss.env`）按这个顺序显示就是乱的。
  /// 这里统一：**目录在前、文件在后**，同类型按名字倒序（备份名 / 日期目录的字典序
  /// 就是时间序），最新的一眼就能看到。
  Future<void> readFiles() async {
    List<String> result = <String>[];
    try {
      final List<FileSystemEntity> entries =
          await Directory(widget.path).list().toList();

      entries.sort((a, b) {
        final bool aDir = FileSystemEntity.isDirectorySync(a.path);
        final bool bDir = FileSystemEntity.isDirectorySync(b.path);
        if (aDir != bDir) return aDir ? -1 : 1;
        return _baseName(b.path).compareTo(_baseName(a.path));
      });

      result = entries.map((e) => e.path).toList();
    } catch (e) {
      e.toString().toast();
    }
    if (!mounted) return;
    setState(() => paths = result);
  }

  String _baseName(String p) => p.split(Platform.pathSeparator).last;

  /// 备份文件名只有时分秒，看不出是哪类备份 —— 这里补一行说明。
  Widget? _fileHint(String name) {
    String text = "";
    if (name.endsWith(".env")) {
      text = "环境变量备份";
    } else if (name.endsWith(".subscribe")) {
      text = "订阅备份";
    } else if (name.endsWith(".config")) {
      text = "配置文件备份";
    }
    if (text.isEmpty) return null;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: ref.watch(themeProvider).themeColor.descColor(),
      ),
    );
  }
}
