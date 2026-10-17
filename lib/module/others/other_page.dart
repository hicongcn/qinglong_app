import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/module/others/dashboard/dashboard_page.dart';
import 'package:qinglong_app/module/others/logs/notify_log_page.dart';
import 'package:qinglong_app/module/others/logs/system_log_page.dart';
import 'package:qinglong_app/module/others/panel_setting/panel_setting_page.dart';
import 'package:qinglong_app/module/others/two_factor/two_factor_page.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:qinglong_app/module/others/sort_account_page.dart';
import 'package:qinglong_app/module/others/text_size_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:path/path.dart' as ints;

import '../../main.dart';
import '../appkey/appkey_page.dart';
import '../home/system_bean.dart';
import '../poet_page.dart';
import '../push_setting_page.dart';
import '../scan_page.dart';
import '../task/task_page.dart';
import '../update_max_account_page.dart';

class OtherPage extends ConsumerStatefulWidget {
  const OtherPage({Key? key}) : super(key: key);

  @override
  OtherPageState createState() => OtherPageState();
}

class OtherPageState extends ConsumerState<OtherPage>
    with LazyLoadState<OtherPage> {
  var toggleValue = false;
  String? userIcon;
  String userName = "青龙客户端";
  var desc = "欢迎使用青龙客户端".obs;
  Map<String, dynamic> poetData = {};

  @override
  void initState() {
    super.initState();
    delLogsByExperiedDate();
  }

  final ScrollController _scrollController = ScrollController();
  GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

  Future<void> move2Top() async {
    if (_scrollController.offset !=
        _scrollController.position.minScrollExtent) {
      await scrollToTop();
    } else {
      if (refreshKey.currentState?.mounted ?? false) {
        await refreshKey.currentState?.show();
      }
    }
  }

  Future<void> scrollToTop() async {
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ref.watch(themeProvider).themeColor.bg2Color(),
      body: RefreshIndicator(
        key: refreshKey,
        onRefresh: () async {
          await loadPoet();
        },
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              bottom: kBottomNavigationBarHeight + 50,
            ),
            child: Column(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: 190,
                  decoration: BoxDecoration(
                    image: (ref.watch(themeProvider).themeMode == modeDark)
                        ? null
                        : const DecorationImage(
                            image:
                                AssetImage('assets/images/icon_other_bg.jpg'),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: kToolbarHeight + 25,
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // VIP 体系已移除：直接进账号切换（单实例模式下不提供）
                          if (SpUtil.getBool(spSingleInstance,
                              defValue: false)) {
                            return;
                          }
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation1, animation2) =>
                                      const ChangeAccountPage(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 15,
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: (userIcon != null && userIcon!.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: userIcon!,
                                      width: 60,
                                      height: 60,
                                      placeholder: (_, __) {
                                        return Image.asset(
                                          _defaultUserAvatar(),
                                          width: 60,
                                          height: 60,
                                        );
                                      },
                                      errorWidget: (_, __, ___) {
                                        return Image.asset(
                                          _defaultUserAvatar(),
                                          width: 60,
                                          height: 60,
                                        );
                                      },
                                    )
                                  : Image.asset(
                                      _defaultUserAvatar(),
                                      width: 60,
                                      height: 60,
                                    ),
                            ),
                            const SizedBox(
                              width: 15,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          (SingleAccountPageState.ofUserInfo(
                                                              context)
                                                          .alias ==
                                                      null ||
                                                  SingleAccountPageState
                                                          .ofUserInfo(context)
                                                      .alias!
                                                      .isEmpty)
                                              ? userName
                                              : SingleAccountPageState
                                                      .ofUserInfo(context)
                                                  .alias!,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: ref
                                                .watch(themeProvider)
                                                .themeColor
                                                .titleColor(),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        fit: FlexFit.loose,
                                      ),

                                    ],
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Obx(
                                    () => GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (poetData.isEmpty) return;
                                        Navigator.of(context).push(
                                          CupertinoPageRoute(
                                            builder: (context) => PoetPage(
                                              data: poetData,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        desc.value,
                                        style: TextStyle(
                                          color: ref
                                              .watch(themeProvider)
                                              .themeColor
                                              .descColor(),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                // 两个板块，按功能归属划分，条目顺序与命名对齐青龙面板的左侧菜单：
                //   仪表盘 → 订阅管理 → 脚本管理 → 依赖管理 → 日志 → 系统设置
                // ⛔ 服务端功能不许放进 App 板块，反之亦然（用户明确要求过）。
                // ⛔ 板块名是「青龙设置」（用户指定）。
                _gridCard(null, <Widget>[ // 青龙侧（服务端能力）
                  _cell("仪表盘",
                      icon: Icons.dashboard_outlined,
                      onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (context) => const DashboardPage()))),
                  _cell("订阅管理",
                      icon: Icons.subscriptions,
                      onTap: () => Navigator.of(context)
                          .pushNamed(Routes.routeSubscribeList)),
                  _cell("脚本管理",
                      icon: Icons.description_outlined,
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.routeScript)),
                  _cell("依赖管理",
                      icon: Icons.extension_outlined,
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.routeDependency)),
                  _cell("任务日志",
                      icon: Icons.receipt_long_outlined,
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.routeTaskLog)),
                  _cell("登录日志",
                      icon: Icons.login,
                      onTap: _loginLog),
                  _cell("系统日志",
                      icon: Icons.terminal,
                      onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                          builder: (context) => const SystemLogPage()))),
                  _cell("通知日志",
                      icon: Icons.notifications_none,
                      onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                          builder: (context) => const NotifyLogPage()))),
                  _cell("通知设置",
                      icon: Icons.mail_outline,
                      onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (context) => const PushSettingPage()))),
                  _cell("应用密钥",
                      icon: Icons.vpn_key_outlined,
                      onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (context) => const AppKeyPage()))),
                  _cell("两步验证",
                      icon: Icons.security,
                      onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                          builder: (context) => const TwoFactorPage()))),
                  _cell("面板设置",
                      icon: Icons.tune,
                      onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (context) =>
                                  const PanelSettingPage()))),
                ]),
                const SizedBox(
                  height: 12,
                ),
                _gridCard(null, <Widget>[ // App 侧（客户端能力）
                  _cell("扫描依赖",
                      icon: Icons.search,
                      onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (context) => const ScanPage()))),
                  _cell("多账号数",
                      icon: Icons.all_inclusive, onTap: _multiAccount),
                  _cell("账号排序",
                      icon: Icons.swap_vert, onTap: _sortAccount),
                  _cell("字体大小",
                      icon: Icons.format_size,
                      onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                          builder: (context) => const TextSizePage()))),
                  _cell("文件备份",
                      icon: Icons.cloud_upload_outlined,
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.routeICloud)),
                  _cell("系统设置",
                      icon: Icons.settings_outlined,
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.routeSetting)),
                  _cell("关于软件",
                      icon: Icons.info_outline,
                      onTap: () =>
                          Navigator.of(context).pushNamed(Routes.routeAbout)),
                ]),
                SizedBox(
                  height: kBottomNavigationBarHeight +
                      MediaQuery.of(context).viewPadding.bottom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _delLog(BuildContext context) async {
    var response = await SingleAccountPageState.ofApi(context).logDel();
    // 老服务端频率在 frequency / info.frequency，2.19+ 在 info.logRemoveFrequency
    String day = response.success
        ? (response.bean?.removeFrequency?.toString() ?? "")
        : "";

    TextEditingController controller = TextEditingController(text: day);
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          "日志删除频率:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("每"),
                  const SizedBox(
                    width: 10,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 3,
                    child: TextField(
                      textAlign: TextAlign.center,
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "",
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .title2Color(),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ref
                                .watch(themeProvider)
                                .themeColor
                                .title2Color(),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      autofocus: false,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  const Text("天"),
                ],
              ),
            ),
          ],
        ),
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
            onPressed: () async {
              Navigator.of(context).pop();
              commitLogDel(
                int.tryParse(controller.text) ?? 1000,
              );
            },
          ),
        ],
      ),
    );
  }

  void commitLogDel(int time) async {
    var response = await SingleAccountPageState.ofApi(context).logDelTime(time);
    if (response.success) {
      "修改成功".toast();
    } else {
      response.message.toast();
    }
  }

  /// 板块卡片：小标题 + 四列网格。
  /// 板块卡片。[title] 传 null 就不画标题 —— 用户觉得两个板块名和整体版式不和谐，
  /// 要求去掉。功能区隔靠图标语义和排序（前 12 个是青龙侧，后 7 个是 App 侧）。
  Widget _gridCard(String? title, List<Widget> cells) {
    final ThemeColors c = ref.watch(themeProvider).themeColor;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 4) {
      final int end = i + 4 > cells.length ? cells.length : i + 4;
      rows.add(_gridRow(cells.sublist(i, end)));
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        color: c.settingBordorColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(fontSize: 13, color: c.descColor()),
            ),
            const SizedBox(
              height: 2,
            ),
          ],
          ...rows,
        ],
      ),
    );
  }

  /// 一行四列。不足四个的用空 Expanded 补位，列宽因此恒定不变。
  Widget _gridRow(List<Widget> cells) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < 4; i++) {
      children.add(Expanded(
        child: i < cells.length ? cells[i] : const SizedBox.shrink(),
      ));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 网格里的一个按钮：图标 + 文字，等宽等高。
  /// 网格里的一个按钮：图标 + 文字，等宽等高。
  ///
  /// 全部用 Material 内置图标：面板那套 `ql-icon-*` 是在线 iconfont，字体文件不在仓库里，
  /// 搬不过来；之前混用 png + Cupertino + Material，字重和留白都不一致。
  Widget _cell(
    String title, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final Color primary = ref.watch(themeProvider).primaryColor;
    final ThemeColors c = ref.watch(themeProvider).themeColor;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              child: Icon(icon, color: primary, size: 26),
            ),
            const SizedBox(
              height: 7,
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.titleColor()),
            ),
          ],
        ),
      ),
    );
  }

  /// 多账号数：单实例模式下多容器同时在线是关掉的，先提示去关
  void _multiAccount() {
    if (SpUtil.getBool(spSingleInstance, defValue: false)) {
      '请先进入 系统设置 关闭单实例模式'.toast();
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => const UpdateMaxAccountPage()),
    );
  }

  void _sortAccount() {
    if (SpUtil.getBool(spSingleInstance, defValue: false)) {
      '请先进入 系统设置 关闭单实例模式'.toast();
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => const SortAccountPage()),
    );
  }

  void _loginLog() {
    if (SingleAccountPageState.ofUserInfo(context).useSecretLogined) {
      "使用client_id方式登录无法获取登录日志".toast();
      return;
    }
    Navigator.of(context).pushNamed(Routes.routeLoginLog);
  }

  /// 默认用户头像（原按 VIP 等级区分，现已统一）
  String _defaultUserAvatar() {
    return "assets/images/ql.png";
  }

  @override
  void onLazyLoad() async {
    var response = await SingleAccountPageState.ofApi(context).user();

    if (response.success) {
      userIcon = response.bean?.avatar;
      userName = response.bean?.username ?? "青龙客户端";
      if (userIcon != null && userIcon!.isNotEmpty) {
        userIcon =
            "${SingleAccountPageState.ofUserInfo(context).host}/api/static/$userIcon";
      }
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadPoet();
    });
  }

  void delLogsByExperiedDate() async {
    try {
      int before = SpUtil.getInt(spLocalBackUpFileExperiedTime,
          defValue: getDefaultLogExperiedTime());
      String now = DateFormat('yyyy-MM-dd').format(DateTime.now()); //获取多少天前的日期

      print("...$before天之前的文件全部删除");

      Directory directory = Directory(
          "${await FileUtil(SingleAccountPageState.of(context)?.index ?? 0).localPath}/");

      List<FileSystemEntity> list = directory.listSync();

      for (FileSystemEntity file in list) {
        String date = ints.basename(file.path);
        var a = DateTime.tryParse(date);
        var b = DateTime.tryParse(now);

        if (a != null && b != null) {
          if (b.difference(a).inDays > before) {
            if (await file.exists()) {
              await file.delete(recursive: true);
              print("删除成功${file.path}");
            }
          } else {
            print("不用删除${file.path}");
          }
        } else {
          print("时间格式出错${file.path}");
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> loadPoet() async {
    try {
      Dio dio = Dio(BaseOptions(
        receiveTimeout: 10000,
        connectTimeout: 10000,
      ));

      if (!SpUtil.haveKey(spPoetToken)) {
        var tokenResponse = await dio.get("https://v2.jinrishici.com/token");

        if (tokenResponse.statusCode == 200) {
          String? token = tokenResponse.data["data"];
          if (token != null && token.isNotEmpty) {
            SpUtil.putString(spPoetToken, token);
          }
        }
      }

      var response = await dio.get("https://v2.jinrishici.com/one.json",
          options: Options(
            headers: {
              "X-User-Token": SpUtil.getString(spPoetToken, defValue: ""),
            },
          ));
      if (response.statusCode == 200) {
        poetData.clear();
        poetData.addAll(response.data as Map<String, dynamic>);
        desc.value = poetData["data"]?["content"]?.toString() ?? "欢迎使用青龙客户端";
      }
    } catch (e) {}
  }
}

/// 本地备份文件默认保留天数（超过该天数的备份会被自动删除）。
/// 原实现按 VIP 分级（VIP 5 天 / 其它 30 天），VIP 体系移除后统一取 30 天
/// —— 保留更久更保守，不会因为默认值把用户的备份删掉。
int getDefaultLogExperiedTime() {
  return 30;
}
