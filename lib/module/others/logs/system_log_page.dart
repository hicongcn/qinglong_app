import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 系统日志（服务端）。
///
/// 对应面板「系统设置 → 系统日志」：`GET /api/system/log?limit=` 取纯文本，
/// `DELETE /api/system/log` 清空。（2.23 里 `/system/log/remove` 已删除，
/// 但读取和清空这两个还在。）
class SystemLogPage extends ConsumerStatefulWidget {
  const SystemLogPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _SystemLogPageState();
}

class _SystemLogPageState extends ConsumerState<SystemLogPage> {
  String _text = "";
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final response = await SingleAccountPageState.ofApi(context).systemLog();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = !response.success;
      _text = response.bean ?? (response.message ?? "");
    });
  }

  void _clear() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("确认清空系统日志吗？"),
        content: const Text("清空后不可恢复。"),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消", style: TextStyle(color: Color(0xff999999))),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            child: Text(
              "清空",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final response =
                  await SingleAccountPageState.ofApi(context).clearSystemLog();
              if (!mounted) return;
              (response.success ? "已清空" : (response.message ?? "清空失败")).toast();
              if (response.success) _load();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors c = ref.watch(themeProvider).themeColor;

    return Scaffold(
      backgroundColor: c.bg2Color(),
      appBar: QlAppBar(
        title: "系统日志",
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _loading ? null : _clear,
            child: Text(
              "清空",
              style: TextStyle(
                color: _loading
                    ? c.descColor()
                    : ref.watch(themeProvider).primaryColor,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.settingBordorColor(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _text.isEmpty
                            ? (_failed ? "读取失败" : "（空）")
                            : _text,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          fontFamily: "Menlo",
                          color: _failed ? const Color(0xffE5484D) : c.titleColor(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
