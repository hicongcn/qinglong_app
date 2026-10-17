import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/others/logs/notify_log_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 通知日志（服务端）。
///
/// 对应面板「系统设置 → 通知日志」：`GET /api/system/notify-log`。
/// 面板里是表格，手机上一列一行；点开看完整内容。
class NotifyLogPage extends ConsumerStatefulWidget {
  const NotifyLogPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _NotifyLogPageState();
}

class _NotifyLogPageState extends ConsumerState<NotifyLogPage> {
  List<NotifyLogBean> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await SingleAccountPageState.ofApi(context).notifyLog();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (response.success) {
        _list = response.bean ?? [];
      } else {
        _error = response.message ?? "读取失败";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors c = ref.watch(themeProvider).themeColor;

    return Scaffold(
      backgroundColor: c.bg2Color(),
      appBar: QlAppBar(title: "通知日志"),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _list.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 120),
                          child: Center(
                            child: Text(
                              _error ?? "暂无通知记录",
                              style: TextStyle(color: c.descColor(), fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 30),
                      itemCount: _list.length,
                      itemBuilder: (context, i) => _item(_list[i], c),
                    ),
            ),
    );
  }

  Widget _item(NotifyLogBean bean, ThemeColors c) {
    final Color statusColor =
        bean.success ? const Color(0xff089556) : const Color(0xffE5484D);
    // bean.time 内部会判断时间戳是秒还是毫秒
    final DateTime? at = bean.time;
    final String time =
        at == null ? "-" : DateFormat('MM-dd HH:mm:ss').format(at);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetail(bean, c),
      child: Container(
        margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.settingBordorColor(),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  time,
                  style: TextStyle(color: c.descColor(), fontSize: 12),
                ),
                const Spacer(),
                Text(
                  bean.success ? "成功" : "失败",
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
                const SizedBox(width: 8),
                if ((bean.notifyType ?? "").isNotEmpty)
                  Text(
                    bean.notifyType!,
                    style: TextStyle(color: c.descColor(), fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              (bean.title ?? "").isEmpty ? "（无标题）" : bean.title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.titleColor(),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (bean.content ?? "").isEmpty ? "（无内容）" : bean.content!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.descColor(), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              bean.sourceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.descColor(), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(NotifyLogBean bean, ThemeColors c) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text((bean.title ?? "").isEmpty ? "通知内容" : bean.title!),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bean.sourceText, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(bean.content ?? "", style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              "关闭",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
