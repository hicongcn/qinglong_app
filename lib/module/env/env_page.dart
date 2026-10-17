import 'dart:convert';

import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/base_state_widget.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/module/env/add_env_page.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/env/env_viewmodel.dart';
import 'package:qinglong_app/module/task/task_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../../base/ui/enable_widget.dart';

class EnvPage extends ConsumerStatefulWidget {
  const EnvPage({Key? key}) : super(key: key);

  @override
  EnvPageState createState() => EnvPageState();
}

class EnvPageState extends ConsumerState<EnvPage> with TickerProviderStateMixin {
  String currentState = EnvViewModel.allStr;
  TextEditingController searchText = TextEditingController();
  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();

  bool editMode = false;
  Set<String> checkedIds = <String>{};
  bool buttonshow = false;
  GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

  Future<void> scrollToTop() async {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }

  Future<void> move2Top() async {
    if (_scrollController.offset != _scrollController.position.minScrollExtent) {
      await scrollToTop();
    } else {
      if (refreshKey.currentState?.mounted ?? false) {
        await refreshKey.currentState?.show();
      }
    }
  }

  List<EnvBean> getListByType(int index) {
    var model = ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)).notifier);
    if (index == 0) {
      return model.list;
    } else if (index == 1) {
      return model.enabledList;
    } else if (index == 2) {
      return model.disabledList;
    }
    return model.list;
  }

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);

    super.initState();
    searchText.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    removeOverlay();
    // 释放控制器，避免页面销毁后仍被持有（内存泄漏）
    _tabController?.dispose();
    _scrollController.dispose();
    searchText.dispose();
    super.dispose();
  }

  double searchCellHeight = 55;

  SliverAppBar _buildAppBar(WidgetRef ref, EnvViewModel model) {
    return SliverAppBar(
      pinned: false,
      floating: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      snap: false,
      primary: false,
      toolbarHeight: searchCellHeight,
      flexibleSpace: searchCell(context, ref, model),
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
        appBar: QlAppBar(
          title: (editMode && checkedIds.isNotEmpty) ? "当前选中 ${checkedIds.length} 个变量" : "环境变量",
          canClick2Vip: !editMode,
          backWidget: Builder(builder: (context) {
            return CupertinoButton(
              color: Colors.transparent,
              padding: EdgeInsets.zero,
              onPressed: () {
                checkedIds.clear();
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  if (editMode) {
                    showOverlay(context);
                  } else {
                    removeOverlay();
                  }
                });
                editMode = !editMode;
                // searchText.text = "";
                setState(() {});
              },
              child: Center(
                child: Text(
                  editMode == true ? "完成" : "编辑",
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).appBarTheme.iconTheme?.color,
                  ),
                ),
              ),
            );
          }),
          actions: [
            CupertinoButton(
              color: Colors.transparent,
              padding: EdgeInsets.zero,
              onPressed: () {
                if (editMode) {
                  if (checkedIds.length ==
                      getListByType(_tabController?.index ?? 0).where((value) {
                        if (searchText.text.isEmpty ||
                            (value.name?.contains(searchText.text.toLowerCase()) ?? false) ||
                            (value.value?.contains(searchText.text.toLowerCase()) ?? false) ||
                            (value.remarks?.contains(searchText.text.toLowerCase()) ?? false)) {
                          return true;
                        } else {
                          return false;
                        }
                      }).length) {
                    //全不选

                    checkedIds.clear();
                    setState(() {});
                  } else {
                    //全选
                    checkedIds.clear();
                    checkedIds.addAll(getListByType(_tabController?.index ?? 0)
                        .where((value) {
                          if (searchText.text.isEmpty ||
                              (value.name?.contains(searchText.text.toLowerCase()) ?? false) ||
                              (value.value?.contains(searchText.text.toLowerCase()) ?? false) ||
                              (value.remarks?.contains(searchText.text.toLowerCase()) ?? false)) {
                            return true;
                          } else {
                            return false;
                          }
                        })
                        .map((e) => e.sId ?? "")
                        .toList());
                    setState(() {});
                  }
                  return;
                }
                Navigator.of(context)
                    .push(
                  CupertinoPageRoute(
                    builder: (context) => const AddEnvPage(),
                  ),
                )
                    .then((value) {
                  ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)).notifier).loadData(context, false);
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ),
                child: Center(
                  child: editMode
                      ? Text(
                          checkedIds.length ==
                                  getListByType(_tabController?.index ?? 0).where((value) {
                                    if (searchText.text.isEmpty ||
                                        (value.name?.contains(searchText.text.toLowerCase()) ?? false) ||
                                        (value.value?.contains(searchText.text.toLowerCase()) ?? false) ||
                                        (value.remarks?.contains(searchText.text.toLowerCase()) ?? false)) {
                                      return true;
                                    } else {
                                      return false;
                                    }
                                  }).length
                              ? "全不选"
                              : "全选",
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).appBarTheme.iconTheme?.color,
                          ),
                        )
                      : Icon(
                          CupertinoIcons.add,
                          size: 24,
                          color: Theme.of(context).appBarTheme.iconTheme?.color,
                        ),
                ),
              ),
            ),
            // 导入：粘贴面板「批量导出」的 JSON，或 NAME=VALUE 一行一条
            if (!editMode)
              CupertinoButton(
                color: Colors.transparent,
                padding: EdgeInsets.zero,
                onPressed: _importEnvs,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.square_arrow_down,
                      size: 22,
                      color: Theme.of(context).appBarTheme.iconTheme?.color,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: BaseStateWidget<EnvViewModel>(
          builder: (ref, model, child) {
            return NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return [
                  _buildAppBar(ref, model),
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      floating: false,
                      delegate: SliverTabBarDelegate(
                        _tabController!,
                        ref,
                        editMode,
                      ),
                    ),
                  ),
                ];
              },
              body: RefreshIndicator(
                key: refreshKey,
                edgeOffset: 15,
                notificationPredicate: (_) {
                  return true;
                },
                color: Theme.of(context).primaryColor,
                onRefresh: () async {
                  return model.loadData(context, false);
                },
                child: SlidableAutoCloseBehavior(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      EnvRecordListView(
                        list: model.list,
                        searchText: searchText.text,
                        editMode: editMode,
                        checked: checkedIds,
                        changed: (id) {
                          if (checkedIds.contains(id)) {
                            checkedIds.remove(id);
                          } else {
                            checkedIds.add(id);
                          }
                          setState(() {});
                        },
                      ),
                      EnvListView(
                        list: model.enabledList,
                        searchText: searchText.text,
                        editMode: editMode,
                        checked: checkedIds,
                        changed: (id) {
                          if (checkedIds.contains(id)) {
                            checkedIds.remove(id);
                          } else {
                            checkedIds.add(id);
                          }
                          setState(() {});
                        },
                      ),
                      EnvListView(
                        list: model.disabledList,
                        searchText: searchText.text,
                        editMode: editMode,
                        checked: checkedIds,
                        changed: (id) {
                          if (checkedIds.contains(id)) {
                            checkedIds.remove(id);
                          } else {
                            checkedIds.add(id);
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          model: SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)),
          onReady: (viewModel) {
            viewModel.loadData(context);
          },
        ),
      ),
    );
  }

  Widget searchCell(BuildContext context, WidgetRef ref, EnvViewModel model) {
    return Container(
      color: ref.watch(themeProvider).themeColor.searchBgColor(),
      padding: const EdgeInsets.only(
        left: 15,
        right: 15,
        top: 10,
        bottom: 10,
      ),
      height: searchCellHeight.toDouble(),
      child: SearchCell(
        controller: searchText,
      ),
    );
  }

  OverlayEntry? _editModeOverlay;

  void showOverlay(BuildContext context) {
    removeOverlay();
    _editModeOverlay = OverlayEntry(
      builder: (BuildContext context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: MediaQuery.of(context).size.width,
            color: ref.watch(themeProvider).currentTheme.bottomNavigationBarTheme.backgroundColor?.withOpacity(1),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: kBottomNavigationBarHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EditModeButton(
                      "启用",
                      icon: Icons.check_circle_outline_sharp,
                      onTap: () {
                        _executeCode(context, "启用");
                      },
                    ),
                    EditModeButton(
                      "禁用",
                      icon: Icons.dnd_forwardslash,
                      onTap: () {
                        _executeCode(context, "禁用");
                      },
                    ),
                    EditModeButton(
                      "改名",
                      icon: CupertinoIcons.pencil,
                      onTap: () {
                        _executeCode(context, "改名");
                      },
                    ),
                    EditModeButton(
                      "导出",
                      icon: CupertinoIcons.square_arrow_up,
                      onTap: () {
                        _executeCode(context, "导出");
                      },
                    ),
                    EditModeButton(
                      "删除",
                      icon: CupertinoIcons.delete,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _executeCode(context, "删除");
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context)?.insert(_editModeOverlay!);
  }

  void _executeCode(BuildContext context, String s) {
    if (checkedIds.isEmpty) {
      "至少选择1个变量".toast();
      return;
    }
    // 改名 / 导出 不走「确认启用禁用删除」那套：一个是输入框，一个是直接写文件
    if (s == "改名") {
      _renameEnvs();
      return;
    }
    if (s == "导出") {
      _exportEnvs();
      return;
    }

    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => CupertinoAlertDialog(
        title: Text("确认$s"),
        content: Text("确认$s吗"),
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
              editMode = false;
              removeOverlay();
              WidgetsBinding.instance.addPostFrameCallback(
                (timeStamp) {
                  if (s == "启用") {
                    enableEnv();
                  } else if (s == "禁用") {
                    disableEnv();
                  } else if (s == "删除") {
                    deleteEnvs();
                  }
                },
              );
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void enableEnv() {
    ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)).notifier).enableEnv(
          context,
          checkedIds.toList(),
          1,
        );
  }

  void disableEnv() {
    ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)).notifier).enableEnv(
          context,
          checkedIds.toList(),
          0,
        );
  }

  void deleteEnvs() {
    ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)).notifier).delEnvs(context, checkedIds.toList());
  }

  /// 批量改名：`PUT /api/envs/name {ids, name}`
  void _renameEnvs() {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context1) => CupertinoAlertDialog(
        title: Text("修改 ${checkedIds.length} 个变量的名称"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(
            controller: controller,
            autofocus: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: "新名称"),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消", style: TextStyle(color: Color(0xff999999))),
            onPressed: () => Navigator.of(context1).pop(),
          ),
          CupertinoDialogAction(
            child: Text(
              "确定",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () async {
              Navigator.of(context1).pop();
              final String name = controller.text.trim();
              if (name.isEmpty) {
                "名称不能为空".toast();
                return;
              }
              final HttpResponse<NullResponse> res =
                  await SingleAccountPageState.ofApi(context)
                      .renameEnvs(checkedIds.toList(), name);
              if (!mounted) return;
              res.message.toast();
              if (res.success) {
                editMode = false;
                removeOverlay();
                checkedIds.clear();
                setState(() {});
                ref
                    .read(SingleAccountPageState.ofEnvProvider(context)(
                            getProviderName(context))
                        .notifier)
                    .loadData(context, false);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 批量导出：和面板一致，导出 `[{value,name,remarks}]` 的 JSON 文件。
  /// 面板还带 labels，客户端没有标签体系，不带。
  void _exportEnvs() async {
    final EnvViewModel vm = ref.read(
        SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)));
    final List<Map<String, dynamic>> data = vm.list
        .where((e) => checkedIds.contains(e.sId))
        .map((e) => <String, dynamic>{
              "value": e.value ?? "",
              "name": e.name ?? "",
              "remarks": e.remarks ?? "",
            })
        .toList();
    if (data.isEmpty) {
      "没有可导出的变量".toast();
      return;
    }
    try {
      final String name = FileUtil.timestampedName("env.json");
      await FileUtil(0).writeDownloadFile(name, jsonEncode(data));
      "已导出 ${data.length} 个变量，写入qinglong_app文件夹下的 $name".toast2();
    } catch (e) {
      e.toString().toast();
    }
  }

  /// 导入：支持面板「批量导出」的 JSON，也支持 `NAME=VALUE` 一行一条。
  void _importEnvs() {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("导入环境变量"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "粘贴面板「批量导出」得到的 JSON；也支持每行一条 NAME=VALUE。",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 4,
                style: const TextStyle(fontSize: 12, fontFamily: "Menlo"),
                decoration: const InputDecoration(
                  hintText: '[{"name":"JD_COOKIE","value":"xxx","remarks":""}]',
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消", style: TextStyle(color: Color(0xff999999))),
            onPressed: () => Navigator.of(context1).pop(),
          ),
          CupertinoDialogAction(
            child: Text(
              "导入",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () async {
              Navigator.of(context1).pop();
              final List<Map<String, dynamic>>? list =
                  _parseEnvInput(controller.text);
              if (list == null) {
                "格式不对：需要 JSON 数组或 NAME=VALUE".toast();
                return;
              }
              if (list.isEmpty) {
                "没有解析到变量".toast();
                return;
              }
              final HttpResponse<NullResponse> res =
                  await SingleAccountPageState.ofApi(context).addEnvs(list);
              if (!mounted) return;
              (res.success ? "已导入 ${list.length} 个变量" : res.message).toast();
              if (res.success) {
                ref
                    .read(SingleAccountPageState.ofEnvProvider(context)(
                            getProviderName(context))
                        .notifier)
                    .loadData(context, false);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 解析导入文本。JSON 数组 → 对象列表；否则按 `NAME=VALUE` 逐行。
  /// 返回 null 表示完全解析不出来。
  List<Map<String, dynamic>>? _parseEnvInput(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return <Map<String, dynamic>>[];

    if (text.startsWith("[") || text.startsWith("{")) {
      try {
        final dynamic decoded = jsonDecode(text);
        final List<dynamic> items = decoded is List ? decoded : <dynamic>[decoded];
        final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
        for (final dynamic item in items) {
          if (item is! Map) continue;
          final String name = (item["name"] ?? "").toString().trim();
          if (name.isEmpty) continue;
          out.add(<String, dynamic>{
            "name": name,
            "value": (item["value"] ?? "").toString(),
            "remarks": (item["remarks"] ?? "").toString(),
          });
        }
        return out;
      } catch (e) {
        return null;
      }
    }

    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final String line in text.split("\n")) {
      final String s = line.trim();
      if (s.isEmpty || s.startsWith("#")) continue;
      final int i = s.indexOf("=");
      if (i <= 0) continue;
      String name = s.substring(0, i).trim();
      String value = s.substring(i + 1).trim();
      // 去掉包裹的引号：NAME='VALUE'
      if (value.length >= 2 &&
          ((value.startsWith("'") && value.endsWith("'")) ||
              (value.startsWith('"') && value.endsWith('"')))) {
        value = value.substring(1, value.length - 1);
      }
      if (name.isEmpty) continue;
      out.add(<String, dynamic>{"name": name, "value": value, "remarks": ""});
    }
    return out;
  }

  void removeOverlay() {
    if (_editModeOverlay != null && _editModeOverlay!.mounted) {
      _editModeOverlay?.remove();
      _editModeOverlay = null;
    }
  }
}

class EnvItemCell extends StatelessWidget {
  final EnvBean bean;
  final int index;
  final WidgetRef ref;
  final bool editMode;
  final bool editMode2;
  final bool checked;
  final ValueChanged<String> checkedCallback;

  const EnvItemCell(
    this.bean,
    this.index,
    this.ref, {
    Key? key,
    this.editMode = false,
    this.editMode2 = false,
    required this.checkedCallback,
    required this.checked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Slidable(
      enabled: !editMode,
      key: ValueKey(bean.sId),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            backgroundColor: const Color(0xff5D5E70),
            onPressed: (_) {
              Navigator.of(context)
                  .push(
                CupertinoPageRoute(
                  builder: (context) => AddEnvPage(
                    envBean: bean,
                  ),
                ),
              )
                  .then((value) {
                ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)).notifier).loadData(context, false);
              });
            },
            foregroundColor: Colors.white,
            icon: CupertinoIcons.pencil_outline,
          ),
          SlidableAction(
            backgroundColor: const Color(0xff4C8DEA),
            onPressed: (_) {
              pinEnv(context);
            },
            foregroundColor: Colors.white,
            icon: bean.isPinned == 1
                ? Icons.push_pin
                : Icons.push_pin_outlined,
          ),
          SlidableAction(
            backgroundColor: const Color(0xffA356D6),
            onPressed: (_) {
              enableEnv(context);
            },
            foregroundColor: Colors.white,
            icon: bean.status == 0 ? Icons.dnd_forwardslash : Icons.check_circle_outline_sharp,
          ),
          SlidableAction(
            backgroundColor: const Color(0xffEA4D3E),
            onPressed: (_) {
              delEnv(context, ref);
            },
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
          ),
        ],
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: ref.watch(themeProvider).themeColor.settingBgColor(),
              child: InkWell(
                onTap: () {
                  if (editMode) {
                    checkedCallback(bean.sId ?? "");
                  } else {
                    Navigator.of(context).pushNamed(Routes.routeEnvDetail, arguments: bean);
                  }
                },
                child: Row(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: SizedBox(
                        width: editMode ? 40 : 0,
                        height: 40,
                        child: Visibility(
                          visible: editMode,
                          child: GestureDetector(
                            child: Icon(
                              checked ? CupertinoIcons.checkmark_alt_circle : CupertinoIcons.circle,
                              size: 25,
                              color: checked ? ref.watch(themeProvider).primaryColor : ref.watch(themeProvider).themeColor.descColor(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: ref.watch(themeProvider).themeColor.descColor(), width: 1),
                                        ),
                                        child: Text(
                                          "${getIndexByIndex(context, index)}",
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).themeColor.descColor(),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      ConstrainedBox(
                                        constraints: BoxConstraints.loose(
                                          Size.fromWidth(
                                            MediaQuery.of(context).size.width * 0.53,
                                          ),
                                        ),
                                        child: RichText(
                      // RichText 不像 Text 那样自动乘 textScaleFactor，不显式传就跟不上「字体大小」设置
                      textScaleFactor: MediaQuery.of(context).textScaleFactor,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            text: bean.name ?? "",
                                            style: TextStyle(
                                              overflow: TextOverflow.ellipsis,
                                              color: ref.watch(themeProvider).themeColor.titleColor(),
                                              fontSize: 16,
                                            ),
                                            children: <TextSpan>[
                                              TextSpan(
                                                text: (bean.remarks == null || bean.remarks!.isEmpty) ? "" : "(${bean.remarks})",
                                                style: TextStyle(
                                                  overflow: TextOverflow.ellipsis,
                                                  color: ref.watch(themeProvider).themeColor.descColor(),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 7,
                                      ),
                                      bean.status == 1
                                          ? const StatusWidget(
                                              title: "已禁用",
                                              color: Color(0xffFB5858),
                                            )
                                          : StatusWidget(
                                              title: "已启用",
                                              color: ref.watch(themeProvider).primaryColor,
                                            )
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  width: 15,
                                ),
                                Visibility(
                                  visible: !editMode2,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      bean.updatedAt == null ? Utils.formatGMTTime(bean.timestamp ?? "") : Utils.formatTime2(bean.updatedAt),
                                      maxLines: 1,
                                      style: TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                        color: ref.watch(themeProvider).themeColor.descColor(),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 15,
                            ),
                            Material(
                              color: Colors.transparent,
                              child: Text(
                                bean.value ?? "",
                                maxLines: 1,
                                style: TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                  color: ref.watch(themeProvider).themeColor.descColor(),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Visibility(
                      visible: editMode2,
                      child: const IgnorePointer(
                        ignoring: true,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                          ),
                          child: Icon(
                            CupertinoIcons.line_horizontal_3,
                            color: Color(0xff999999),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(
              height: 1,
              indent: 15,
            ),
          ],
        ),
      ),
    );
  }

  void pinEnv(BuildContext context) {
    ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)))
        .pinEnv(context, [bean.sId!], bean.isPinned != 1);
  }

  void enableEnv(BuildContext context) {
    ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context))).enableEnv(context, [bean.sId!], bean.status!);
  }

  void delEnv(BuildContext context1, WidgetRef ref) {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context1,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("确认删除"),
        content: Text("确认删除环境变量 ${bean.name ?? ""} 吗"),
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
              ref.read(SingleAccountPageState.ofEnvProvider(context1)(getProviderName(context1))).delEnv(context1, bean.sId!);
            },
          ),
        ],
      ),
    );
  }

  int getIndexByIndex(BuildContext context, int index) {
    return index + 1;
  }
}

class EnvListView extends ConsumerStatefulWidget {
  final List<EnvBean> list;
  final String searchText;
  final bool editMode;
  final Set<String> checked;
  final ValueChanged<String> changed;

  const EnvListView({
    Key? key,
    required this.list,
    required this.searchText,
    required this.editMode,
    required this.checked,
    required this.changed,
  }) : super(key: key);

  @override
  ConsumerState<EnvListView> createState() => _EnvListViewState();
}

class _EnvListViewState extends ConsumerState<EnvListView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListView.builder(
      padding: const EdgeInsets.only(
        bottom: kBottomNavigationBarHeight + 50,
        top: kToolbarHeight,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int i) {
        EnvBean value = widget.list[i];
        if (widget.searchText.isEmpty ||
            (value.name?.contains(widget.searchText) ?? false) ||
            (value.value?.contains(widget.searchText) ?? false) ||
            (value.remarks?.contains(widget.searchText) ?? false)) {
          return EnvItemCell(
            value,
            i,
            ref,
            key: ValueKey(value.sId),
            editMode: widget.editMode,
            editMode2: false,
            checkedCallback: (id) {
              widget.changed(id);
            },
            checked: widget.checked.contains(value.sId),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
      itemCount: widget.list.length,
    );
  }
}

class EnvRecordListView extends ConsumerStatefulWidget {
  final List<EnvBean> list;
  final String searchText;
  final bool editMode;
  final Set<String> checked;
  final ValueChanged<String> changed;

  const EnvRecordListView({
    Key? key,
    required this.list,
    required this.searchText,
    required this.editMode,
    required this.checked,
    required this.changed,
  }) : super(key: key);

  @override
  ConsumerState<EnvRecordListView> createState() => _EnvRecordListViewState();
}

class _EnvRecordListViewState extends ConsumerState<EnvRecordListView> with AutomaticKeepAliveClientMixin {
  final List<EnvItemCell> list = [];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    list.clear();
    for (int i = 0; i < widget.list.length; i++) {
      EnvBean value = widget.list[i];
      if (widget.searchText.isEmpty ||
          (value.name?.contains(widget.searchText) ?? false) ||
          (value.value?.contains(widget.searchText) ?? false) ||
          (value.remarks?.contains(widget.searchText) ?? false)) {
        list.add(
          EnvItemCell(
            value,
            i,
            ref,
            key: ValueKey(value.sId),
            editMode: widget.editMode,
            editMode2: widget.editMode,
            checkedCallback: (id) {
              widget.changed(id);
            },
            checked: widget.checked.contains(value.sId),
          ),
        );
      }
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        bottom: kBottomNavigationBarHeight + 50,
        top: kToolbarHeight,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      onReorder: (int oldIndex, int newIndex) {
        if (widget.searchText.isNotEmpty) {
          "请先清空搜索关键词".toast();
          return;
        }

        setState(
          () {
            //交换数据
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final EnvBean item = widget.list.removeAt(oldIndex);
            widget.list.insert(newIndex, item);

            ref.read(SingleAccountPageState.ofEnvProvider(context)(getProviderName(context)).notifier).update(context, item.sId ?? "", newIndex, oldIndex);
          },
        );
      },
      children: list,
    );
  }
}

class SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final WidgetRef ref;

  final bool editMode;

  const SliverTabBarDelegate(
    this.tabController,
    this.ref,
    this.editMode,
  );

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: 55,
      child: IgnorePointer(
        ignoring: editMode,
        child: ColoredBox(
          color: ref.watch(themeProvider).currentTheme.scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              bottom: 10,
              top: 10,
            ),
            child: CustomSlidingSegmentedControl<int>(
              initialValue: 0,
              height: 35,
              isStretch: true,
              children: {
                0: Text(
                  EnvViewModel.allStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: ref.watch(themeProvider).themeColor.title2Color(),
                  ),
                ),
                1: Text(
                  EnvViewModel.enabledStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: ref.watch(themeProvider).themeColor.title2Color(),
                  ),
                ),
                2: Text(
                  EnvViewModel.disabledStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: ref.watch(themeProvider).themeColor.title2Color(),
                  ),
                ),
              },
              decoration: BoxDecoration(
                color: ref.watch(themeProvider).themeColor.segmentedUnCheckBg(),
                borderRadius: BorderRadius.circular(8),
              ),
              thumbDecoration: BoxDecoration(
                color: ref.watch(themeProvider).themeColor.blackAndWhite(),
                borderRadius: BorderRadius.circular(6),
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInToLinear,
              onValueChanged: (v) {
                tabController.index = v;
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(SliverTabBarDelegate oldDelegate) {
    return true;
  }

  @override
  double get maxExtent => 55;

  @override
  double get minExtent => 55;
}
