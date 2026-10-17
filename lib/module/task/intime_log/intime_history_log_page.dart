import 'dart:ui';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../../base/cupertino_sheet.dart';
import '../../../main.dart';
import '../../home/system_bean.dart';

class InTimeHistoryLogPage extends StatefulWidget {
  final String title;
  final String path;

  const InTimeHistoryLogPage({
    Key? key,
    required this.title,
    required this.path,
  }) : super(key: key);

  @override
  _InTimeHistoryLogPageState createState() => _InTimeHistoryLogPageState();
}

class _InTimeHistoryLogPageState extends State<InTimeHistoryLogPage> with LazyLoadState<InTimeHistoryLogPage> {
  String? content;

  bool isRequest = false;
  bool canRequest = true;

  getLogData() async {
    HttpResponse<String> response = await SingleAccountPageState.ofApi(context).taskLogDetail(
      widget.title,
      widget.path,
    );

    if (response.success) {
      content = response.bean;
      setState(() {});
    } else {
      (response.message ?? "").toast();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              showMoreOperate(
                context,
                [
                  CupertinoSheer(
                    title: "分享",
                    onTap: () async {
                      shareTextContent(context, content);
                    },
                  ),
                  addDivider(),
                  CupertinoSheer(
                    title: "下载",
                    onTap: () async {
                      try {
                        // `title` 只是日志文件名（2026-10-17-12-05-00-298.log），
                        // 不含脚本名；`path` 才是它所在的脚本目录（如 elm_天天夺宝）。
                        // 统一成「脚本名_时间.log」，和实时日志、脚本下载保持一致。
                        final String base = widget.path.isNotEmpty
                            ? widget.path
                            : widget.title;
                        final String name = FileUtil.timestampedName(
                            FileUtil.withLogExtension(base));
                        await FileUtil(0).writeDownloadFile(name, content ?? "");
                        "已写入qinglong_app文件夹下,文件名$name".toast2();
                      } catch (e) {
                        e.toString().toast();
                      }
                    },
                  ),
                  addDivider(),
                  CupertinoSheer(
                    title: "删除",
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      deleteFold(widget.title, widget.path);
                    },
                  ),
                ],
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Center(
                child: Icon(
                  Icons.more_horiz,
                  size: 26,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ),
            ),
          )
        ],
        title: widget.title,
      ),
      body: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: (content == null)
              ? const Center(
                  child: LoadingWidget(),
                )
              : CupertinoScrollbar(
                  child: SingleChildScrollView(
                    primary: true,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ExtendedText(
                      content!,
                      selectionHeightStyle: BoxHeightStyle.max,
                      selectionEnabled: true,
                      selectionWidthStyle: BoxWidthStyle.max,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void onLazyLoad() {
    getLogData();
  }

  void deleteFold(String title, String path) async {
    EasyLoading.show(status: "删除中...");
    var temp = await SingleAccountPageState.ofApi(context).deleteLog(title, path);
    EasyLoading.dismiss();
    if (temp.success) {
      "已删除".toast();
      Navigator.of(context).pop(true);
    } else {
      temp.message.toast();
    }
  }
}
