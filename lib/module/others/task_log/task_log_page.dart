import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';
import 'package:qinglong_app/module/task/intime_log/intime_history_log_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';

import '../../../main.dart';
import '../../home/system_bean.dart';

class TaskLogPage extends ConsumerStatefulWidget {
  final String? searchText;

  const TaskLogPage({
    Key? key,
    this.searchText,
  }) : super(key: key);

  @override
  _TaskLogPageState createState() => _TaskLogPageState();
}

class _TaskLogPageState extends ConsumerState<TaskLogPage> with LazyLoadState<TaskLogPage> {
  List<TaskLogBean> list = [];

  TextEditingController searchText = TextEditingController();

  ScrollController controller = ScrollController();

  bool buttonshow = false;

  void scrollToTop() {
    controller.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(floatingButtonVisibility);
    searchText.addListener(() {
      setState(() {});
    });
  }

  void floatingButtonVisibility() {
    double y = controller.offset;
    if (y > MediaQuery.of(context).size.height / 2) {
      if (buttonshow == true) return;
      setState(() {
        buttonshow = true;
      });
    } else {
      if (buttonshow == false) return;
      setState(() {
        buttonshow = false;
      });
    }
  }

  Widget searchCell(WidgetRef context) {
    return Container(
      color: ref.watch(themeProvider).themeColor.searchBgColor(),
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      child: SearchCell(
        controller: searchText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        floatingActionButton: Visibility(
          visible: buttonshow,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              scrollToTop();
            },
            elevation: 2,
            child: const Icon(CupertinoIcons.up_arrow),
          ),
        ),
        appBar: QlAppBar(
          canBack: true,
          backCall: () {
            Navigator.of(context).pop();
          },
          title: "任务日志",
        ),
        body: list.isEmpty
            ? const Center(
                child: LoadingWidget(),
              )
            : SlidableAutoCloseBehavior(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 50),
                  controller: controller,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return searchCell(ref);
                    }
                    TaskLogBean item = list[index - 1];

                    if (searchText.text.isNotEmpty && !(item.name?.contains(searchText.text) ?? false)) {
                      return const SizedBox.shrink();
                    }

                    if ((item.isDir ?? false)) {
                      return Slidable(
                        key: ValueKey(item.name ?? ""),
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.2,
                          children: [
                            SlidableAction(
                              backgroundColor: const Color(0xffEA4D3E),
                              onPressed: (_) {
                                showCupertinoDialog(
                                  context: context,
                                  useRootNavigator: false,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text("确认删除"),
                                    content: const Text("确定删除这个文件夹吗"),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text(
                                          "取消",
                                          style: TextStyle(
                                            color: Color(0xff999999),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      CupertinoDialogAction(
                                        child: Text(
                                          "确定",
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).primaryColor,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          deleteFold(item);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              foregroundColor: Colors.white,
                              icon: CupertinoIcons.delete,
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          title: Text(
                            item.name ?? "",
                            style: TextStyle(
                              color: ref.watch(themeProvider).themeColor.titleColor(),
                              fontSize: 16,
                            ),
                          ),
                          children: (item.files?.isNotEmpty ?? false)
                              ? item.files!
                                  .map((e) => ListTile(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            CupertinoPageRoute(
                                              builder: (context) => InTimeHistoryLogPage(
                                                path: item.name ?? "",
                                                title: e,
                                              ),
                                            ),
                                          );
                                        },
                                        title: Text(
                                          e,
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).themeColor.titleColor(),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ))
                                  .toList()
                              : (item.children ?? [])
                                  .map((e) => ListTile(
                                        onTap: () {
                                          Navigator.of(context)
                                              .push(
                                            CupertinoPageRoute(
                                              builder: (context) => InTimeHistoryLogPage(
                                                path: item.name ?? "",
                                                title: e.title ?? "",
                                              ),
                                            ),
                                          )
                                              .then((value) {
                                            if (value != null && value == true) {
                                              loadData();
                                            }
                                          });
                                        },
                                        title: Text(
                                          e.title ?? "",
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).themeColor.titleColor(),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                        ),
                      );
                    } else {
                      return Slidable(
                        key: ValueKey(item.name ?? ""),
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.4,
                          children: [
                            // 下载：面板「日志管理 → 下载」，走 /logs/download
                            SlidableAction(
                              backgroundColor: ref.watch(themeProvider).primaryColor,
                              onPressed: (_) {
                                downloadLog(item);
                              },
                              foregroundColor: Colors.white,
                              icon: CupertinoIcons.square_arrow_down,
                            ),
                            SlidableAction(
                              backgroundColor: const Color(0xffEA4D3E),
                              onPressed: (_) {
                                showCupertinoDialog(
                                  context: context,
                                  useRootNavigator: false,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text("确认删除"),
                                    content: const Text("确定删除这个文件吗"),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text(
                                          "取消",
                                          style: TextStyle(
                                            color: Color(0xff999999),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      CupertinoDialogAction(
                                        child: Text(
                                          "确定",
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).primaryColor,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          deleteFold(item);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              foregroundColor: Colors.white,
                              icon: CupertinoIcons.delete,
                            ),
                          ],
                        ),
                        child: ListTile(
                          onTap: () {
                            if (item.isDir ?? false) {
                              "该文件夹为空".toast();
                              return;
                            }

                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => InTimeHistoryLogPage(
                                  path: "",
                                  title: item.name ?? "",
                                ),
                              ),
                            );
                          },
                          title: Text(
                            item.name ?? "",
                            style: TextStyle(
                              color: ref.watch(themeProvider).themeColor.titleColor(),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  itemCount: list.length + 1,
                ),
              ),
      ),
    );
  }

  Future<void> loadData() async {
    HttpResponse<List<TaskLogBean>> response = await SingleAccountPageState.ofApi(context).taskLog();

    if (response.success) {
      if (response.bean == null || response.bean!.isEmpty) {
        "暂无数据".toast();
      }
      list.clear();
      list.addAll(response.bean ?? []);
      if (widget.searchText != null) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          searchText.text = widget.searchText!;
        });
      }
      setState(() {});
    } else {
      response.message?.toast();
    }
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  /// 下载日志文件正文。
  ///
  /// 老接口 `GET /api/logs/<file>` 已下线（固定 410），面板改用
  /// `GET /api/logs/download?filename=&path=`（纯文本），这里同样走那个。
  void downloadLog(TaskLogBean item) async {
    EasyLoading.show(status: "下载中...");
    final res = await SingleAccountPageState.ofApi(context)
        .logFileContent(item.name ?? "", "");
    EasyLoading.dismiss();
    if (!res.success) {
      res.message.toast();
      return;
    }
    try {
      // 带时间戳，避免同名重复下载互相覆盖
      final String name = FileUtil.timestampedName(item.name ?? "log.txt");
      await FileUtil(0).writeDownloadFile(name, res.bean ?? "");
      "已写入qinglong_app文件夹下,文件名$name".toast2();
    } catch (e) {
      e.toString().toast();
    }
  }

  void deleteFold(TaskLogBean item) async {
    EasyLoading.show(status: "删除中...");
    var temp = item.isDir == true
        ? await SingleAccountPageState.ofApi(context).deleteLogFold(item.name ?? "", "")
        : await SingleAccountPageState.ofApi(context).deleteLog(item.name ?? "", "");
    EasyLoading.dismiss();
    if (temp.success) {
      "已删除".toast();
      await loadData();
    } else {
      temp.message.toast();
    }
  }
}
