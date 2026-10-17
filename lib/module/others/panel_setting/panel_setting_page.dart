import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 面板设置（服务端）。
///
/// 只放**面板侧**能改的东西，客户端偏好一律去 `setting_page.dart`。
/// 目前两项：
///  - 任务并发数 `info.cronConcurrency`（2.23 取代了 `MaxConcurrentNum`）。
///    默认 `max(cpus, 4)`，核多的机器默认值偏高 → OOMKilled → 容器重启 →
///    running 任务全被标成 stopped，这是「任务跑到一半自己停了」的高发原因之一。
///  - 面板版本 + 检查更新（`GET /api/system/update-check`）。
class PanelSettingPage extends ConsumerStatefulWidget {
  const PanelSettingPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _PanelSettingPageState();
}

class _PanelSettingPageState extends ConsumerState<PanelSettingPage> {
  int? _concurrency;
  int? _logKeepDays;
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await SingleAccountPageState.ofApi(context).logDel();
    if (!mounted) return;
    setState(() {
      _concurrency = response.bean?.info?.cronConcurrency;
      _logKeepDays = response.bean?.info?.logRemoveFrequency;
      _loading = false;
    });
  }

  String _version() {
    try {
      return getIt<SystemBean>(
                  instanceName:
                      (SingleAccountPageState.of(context)?.index ?? 0).toString())
              .version ??
          "-";
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors c = ref.watch(themeProvider).themeColor;

    return Scaffold(
      backgroundColor: c.bg2Color(),
      appBar: QlAppBar(
        title: "面板设置",
      ),
      body: SingleChildScrollView(
        primary: true,
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("任务", c),
            _card(c, [
              _row(
                c,
                icon: CupertinoIcons.square_stack_3d_up,
                title: "任务并发数",
                value: _loading ? "读取中" : (_concurrency?.toString() ?? "-"),
                onTap: _loading ? null : () => _editConcurrency(c),
              ),
            ]),
            _sectionTitle("面板", c),
            _card(c, [
              _row(
                c,
                icon: CupertinoIcons.info_circle,
                title: "面板版本",
                value: _version(),
                onTap: null,
              ),
              _row(
                c,
                icon: CupertinoIcons.refresh,
                title: "检查更新",
                value: _checking ? "检查中" : "",
                onTap: _checking ? null : _checkUpdate,
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 12, 30, 0),
              child: Text(
                "并发数是同时运行的任务上限。默认按 CPU 核数取值，核多时容易把容器撑爆（OOMKilled），"
                "表现就是任务跑到一半没了、日志停在半截。调小一点更稳。",
                style: TextStyle(color: c.descColor(), fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 版式

  Widget _sectionTitle(String text, ThemeColors c) => Padding(
        padding: const EdgeInsets.only(left: 30, top: 15, bottom: 10),
        child: Text(text, style: TextStyle(color: c.descColor(), fontSize: 12)),
      );

  Widget _card(ThemeColors c, List<Widget> items) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) children.add(const Divider(indent: 50, height: 1));
      children.add(items[i]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: c.settingBordorColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(
    ThemeColors c, {
    required IconData icon,
    required String title,
    String? value,
    VoidCallback? onTap,
  }) {
    final Color primary = ref.watch(themeProvider).primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              Icon(icon, color: primary, size: 20),
              const SizedBox(width: 15),
              Text(title, style: TextStyle(color: c.titleColor(), fontSize: 16)),
              const Spacer(),
              if (value != null && value.isNotEmpty)
                Text(value, style: TextStyle(color: c.descColor(), fontSize: 14)),
              if (onTap != null) ...[
                const SizedBox(width: 5),
                Icon(CupertinoIcons.right_chevron, size: 16, color: c.descColor()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 交互

  Future<void> _editConcurrency(ThemeColors c) async {
    final TextEditingController controller =
        TextEditingController(text: _concurrency?.toString() ?? "");
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("任务并发数"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: "例如 2"),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消", style: TextStyle(color: Color(0xff999999))),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            child: Text(
              "保存",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final int? value = int.tryParse(controller.text.trim());
              if (value == null || value < 1) {
                "请输入大于 0 的整数".toast();
                return;
              }
              final response =
                  await SingleAccountPageState.ofApi(context).updateCronConcurrency(value);
              if (!mounted) return;
              response.message.toast();
              if (response.success) _load();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final response = await SingleAccountPageState.ofApi(context).checkUpdate();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!response.success) {
      response.message.toast();
      return;
    }
    final bean = response.bean;
    if (bean?.hasNewVersion ?? false) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text("发现新版本 ${bean?.lastVersion ?? ""}"),
          content: SingleChildScrollView(
            child: Text(bean?.lastLog ?? "", style: const TextStyle(fontSize: 13)),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(
                "知道了",
                style: TextStyle(color: ref.watch(themeProvider).primaryColor),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } else {
      "已是最新版本".toast();
    }
  }
}
