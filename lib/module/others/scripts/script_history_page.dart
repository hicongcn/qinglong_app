import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/others/scripts/script_history_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 脚本编辑历史。
///
/// 数据来自青龙 2.23+ 的三个接口（详见 [ScriptHistoryListBean] 的注释）：
/// 面板里**保存**脚本时会自动留档，最多保留 20 个版本；从 App/CLI 直接上传
/// 不记录历史。所以这里列表为空通常意味着"还没在面板里改过这个脚本"。
class ScriptHistoryPage extends ConsumerStatefulWidget {
  final String title;
  final String? path;

  const ScriptHistoryPage({
    Key? key,
    required this.title,
    this.path,
  }) : super(key: key);

  @override
  _ScriptHistoryPageState createState() => _ScriptHistoryPageState();
}

class _ScriptHistoryPageState extends ConsumerState<ScriptHistoryPage>
    with LazyLoadState<ScriptHistoryPage> {
  ScriptHistoryListBean? data;
  String? error;
  bool loading = true;

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    final HttpResponse<ScriptHistoryListBean> result =
        await SingleAccountPageState.ofApi(context)
            .scriptHistoryList(widget.title, widget.path);

    if (!mounted) return;
    setState(() {
      loading = false;
      if (result.success && result.bean != null) {
        data = result.bean;
      } else {
        error = result.message ?? "获取历史版本失败";
      }
    });
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  Future<void> openDetail(ScriptHistoryVersion version) async {
    final String? id = version.id;
    if (id == null || id.isEmpty) return;

    final bool? changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => ScriptHistoryDetailPage(
          title: widget.title,
          path: widget.path,
          id: id,
        ),
      ),
    );

    if (changed == true && mounted) {
      // 发生过回滚：把结果继续往上传（脚本详情页据此重新读取内容）
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors themeColor = ref.watch(themeProvider).themeColor;

    return Scaffold(
      backgroundColor: themeColor.settingBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          Navigator.of(context).pop();
        },
        title: "编辑历史",
      ),
      body: SafeArea(top: false, child: _buildBody(themeColor)),
    );
  }

  Widget _buildBody(ThemeColors themeColor) {
    if (loading) {
      return const Center(child: LoadingWidget());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: themeColor.descColor()),
              ),
              const SizedBox(height: 14),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: ref.watch(themeProvider).primaryColor,
                onPressed: loadData,
                child: const Text("重试", style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    final List<ScriptHistoryVersion> versions = data?.versions ?? <ScriptHistoryVersion>[];
    if (versions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            "暂无历史版本\n\n在青龙面板里保存该脚本时会自动留档，最多保留 ${data?.limit ?? 20} 个版本。",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: themeColor.descColor()),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: versions.length,
      separatorBuilder: (context, index) => Divider(
        height: 0.5,
        thickness: 0.5,
        color: themeColor.settingBordorColor(),
      ),
      itemBuilder: (context, index) => _buildItem(versions[index], themeColor),
    );
  }

  Widget _buildItem(ScriptHistoryVersion version, ThemeColors themeColor) {
    final bool isCurrent = version.identical == true;

    return InkWell(
      onTap: () => openDetail(version),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        version.sourceLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: themeColor.titleColor(),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor.settingBordorColor(),
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                          ),
                          child: Text(
                            "与当前一致",
                            style: TextStyle(fontSize: 11, color: themeColor.hintColor()),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${version.timeLabel}${version.sizeLabel.isEmpty ? "" : "  ·  ${version.sizeLabel}"}",
                    style: TextStyle(fontSize: 12, color: themeColor.descColor()),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: themeColor.hintColor(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个历史版本：查看内容并回滚。
class ScriptHistoryDetailPage extends ConsumerStatefulWidget {
  final String title;
  final String? path;
  final String id;

  const ScriptHistoryDetailPage({
    Key? key,
    required this.title,
    this.path,
    required this.id,
  }) : super(key: key);

  @override
  _ScriptHistoryDetailPageState createState() => _ScriptHistoryDetailPageState();
}

class _ScriptHistoryDetailPageState extends ConsumerState<ScriptHistoryDetailPage>
    with LazyLoadState<ScriptHistoryDetailPage> {
  ScriptHistoryDetailBean? data;
  String? error;
  bool loading = true;

  /// 是否显示"服务端当前内容"（用于和选中的历史版本对照）
  bool showCurrent = false;
  bool restoring = false;

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    final HttpResponse<ScriptHistoryDetailBean> result =
        await SingleAccountPageState.ofApi(context)
            .scriptHistoryDetail(widget.title, widget.path, widget.id);

    if (!mounted) return;
    setState(() {
      loading = false;
      if (result.success && result.bean != null) {
        data = result.bean;
      } else {
        error = result.message ?? "获取版本内容失败";
      }
    });
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  Future<void> restore() async {
    final ScriptHistoryDetailBean? d = data;
    final String? hash = d?.currentHash;
    if (d == null || hash == null || hash.isEmpty || restoring) return;

    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text("回滚到该版本"),
        content: const Text(
          "将用这个历史版本覆盖当前脚本内容。\n\n回滚前，当前内容也会被记入历史，所以之后还能再切回来。",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消", style: TextStyle(color: Color(0xff999999))),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          CupertinoDialogAction(
            child: const Text("确定回滚"),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => restoring = true);
    EasyLoading.show(status: "回滚中...");

    final Api api = SingleAccountPageState.ofApi(context);
    final HttpResponse<NullResponse> result =
        await api.scriptHistoryRestore(widget.title, widget.path, widget.id, hash);

    await EasyLoading.dismiss();
    if (!mounted) return;
    setState(() => restoring = false);

    if (result.success) {
      "已回滚到该版本".toast();
      Navigator.of(context).pop(true);
    } else {
      // 409 = 期间文件被别人改过：提示后重新拉取（hash 已经变了）
      (result.message ?? "回滚失败").toast();
      loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors themeColor = ref.watch(themeProvider).themeColor;
    final String? body = showCurrent ? data?.current : data?.version?.content;

    return Scaffold(
      backgroundColor: themeColor.codeBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          Navigator.of(context).pop();
        },
        title: widget.title,
        actions: [
          if (data != null)
            CupertinoButton(
              color: Colors.transparent,
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() => showCurrent = !showCurrent);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Center(
                  child: Text(
                    showCurrent ? "看历史版本" : "看当前版本",
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).appBarTheme.iconTheme?.color,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: LoadingWidget())
            : (error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: themeColor.descColor()),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        color: themeColor.settingBordorColor(),
                        child: Text(
                          showCurrent
                              ? "当前服务端内容"
                              : "历史版本 · ${data?.version?.sourceLabel ?? ""} · ${data?.version?.timeLabel ?? ""}",
                          style: TextStyle(fontSize: 12, color: themeColor.descColor()),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: SelectableText(
                              body ?? "",
                              style: const TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ),
                        ),
                      ),
                      if (!showCurrent)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            color: ref.watch(themeProvider).primaryColor,
                            onPressed: restoring ? null : restore,
                            child: const Text("恢复此版本", style: TextStyle(fontSize: 15)),
                          ),
                        ),
                    ],
                  )),
      ),
    );
  }
}
