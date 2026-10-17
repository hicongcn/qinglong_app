import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/home/home_page.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/home/version_history_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../base/ql_app_bar.dart';

/// App 设置页。
///
/// 版式约定（整页只此一套，别再局部改）：
///  - 分组标题 + 一张卡片，卡片内条目由 [_card] 自动插分割线；
///  - 所有条目都走 [_rowShell]，避免每项各自手写 Padding>Row 造成缩进漂移；
///  - 危险操作（退出登录）单独一张卡片、红字，不用整屏宽的大按钮。
class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  /// 红色，两套主题下都够醒目
  static const Color _danger = Color(0xffE5484D);

  /// 当前外观的文字描述
  String _appearanceLabel() {
    if (SpUtil.getBool(spThemeFollowSystem, defValue: false)) {
      return "跟随系统";
    }
    final int style = SpUtil.getInt(spThemeStyle, defValue: modeWhite);
    if (style == modeDark) return "深色";
    if (style == modeWhite) return "白色";
    return "浅色";
  }

  /// 选外观。原来是「白色主题 / 黑色主题 / 跟随系统」三个并列开关，
  /// 既占地方又容易看错，合并成一个选择器。
  Future<void> _pickAppearance() async {
    final bool follow = SpUtil.getBool(spThemeFollowSystem, defValue: false);
    final int style = SpUtil.getInt(spThemeStyle, defValue: modeWhite);

    final String? picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("外观"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop("follow"),
            child: Text("跟随系统${follow ? "（当前）" : ""}"),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop("light"),
            child: Text("浅色${!follow && style == modeLight ? "（当前）" : ""}"),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop("white"),
            child: Text("白色${!follow && style == modeWhite ? "（当前）" : ""}"),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop("dark"),
            child: Text("深色${!follow && style == modeDark ? "（当前）" : ""}"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("取消"),
        ),
      ),
    );

    if (picked == null) return;
    // 注意别用 themeProvider 当变量名，会和全局 provider 撞名
    final theme = ref.read(themeProvider.notifier);
    if (picked == "follow") {
      SpUtil.putBool(spThemeFollowSystem, true);
      theme.changeThemeWithSystemStatus();
    } else {
      SpUtil.putBool(spThemeFollowSystem, false);
      final int target = picked == "dark"
          ? modeDark
          : (picked == "white" ? modeWhite : modeLight);
      theme.changeTheme(target);
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- 版式零件

  Widget _sectionTitle(String text, ThemeColors c) => Padding(
        padding: const EdgeInsets.only(left: 30, top: 15, bottom: 10),
        child: Text(
          text,
          style: TextStyle(color: c.descColor(), fontSize: 12),
        ),
      );

  /// 卡片外壳。条目之间自动补分割线，调用方只管给条目。
  Widget _card(ThemeColors c, List<Widget> items) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(const Divider(indent: 55, height: 1));
      }
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

  /// 单行条目：图标 + 标题 + （可选小问号）+ 右侧内容，整行可点。
  Widget _rowShell({
    required IconData icon,
    required String title,
    required Widget trailing,
    Widget? titleSuffix,
    Color? tint,
    VoidCallback? onTap,
  }) {
    final ThemeColors c = ref.watch(themeProvider).themeColor;
    final Color primary = ref.watch(themeProvider).primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Row(
          children: [
            Icon(icon, color: tint ?? primary, size: 20),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: tint ?? c.titleColor(),
                fontSize: 16,
              ),
            ),
            if (titleSuffix != null) ...[
              const SizedBox(width: 5),
              titleSuffix,
            ],
            const Spacer(),
            trailing,
          ],
        ),
      ),
    );
  }

  /// 开关条目
  Widget _switchRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? titleSuffix,
  }) {
    return _rowShell(
      icon: icon,
      title: title,
      titleSuffix: titleSuffix,
      trailing: Transform.scale(
        scale: 0.9,
        child: CupertinoSwitch(
          activeColor: ref.watch(themeProvider).primaryColor,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// 跳转条目：右侧是「当前值 + 箭头」
  Widget _navRow({
    required IconData icon,
    required String title,
    String? value,
    VoidCallback? onTap,
  }) {
    final ThemeColors c = ref.watch(themeProvider).themeColor;
    return _rowShell(
      icon: icon,
      title: title,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null && value.isNotEmpty)
            Text(
              value,
              style: TextStyle(color: c.descColor(), fontSize: 14),
            ),
          const SizedBox(width: 5),
          Icon(
            CupertinoIcons.right_chevron,
            size: 16,
            color: c.descColor(),
          ),
        ],
      ),
    );
  }

  /// 动作条目：居中或左对齐的纯文字操作（危险操作用红色）
  Widget _actionRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return _rowShell(
      icon: icon,
      title: title,
      tint: _danger,
      onTap: onTap,
      trailing: const SizedBox.shrink(),
    );
  }

  // ---------------------------------------------------------------- 页面

  @override
  Widget build(BuildContext context) {
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(
          instanceName:
              (SingleAccountPageState.of(context)?.index ?? 0).toString());
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }

    final ThemeColors c = ref.watch(themeProvider).themeColor;
    final bool manualVersion = !(systemBean.fromAutoGet ?? false);

    return Scaffold(
      backgroundColor: c.bg2Color(),
      appBar: QlAppBar(
        title: "设置",
      ),
      body: SingleChildScrollView(
        primary: true,
        // 底部留出余量，最后一行不至于贴着屏幕边缘
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("App 设置", c),
            _card(c, [
              _navRow(
                icon: CupertinoIcons.circle_lefthalf_fill,
                title: "外观",
                value: _appearanceLabel(),
                onTap: _pickAppearance,
              ),
              _switchRow(
                icon: CupertinoIcons.doc_text,
                title: "任务自动弹出日志",
                value: SpUtil.getBool(spAutoShowLog, defValue: true),
                onChanged: (open) async {
                  await SpUtil.putBool(spAutoShowLog, open);
                  setState(() {});
                },
              ),
              _switchRow(
                icon: Icons.abc_sharp,
                title: "代码显示行号",
                value: SpUtil.getBool(spShowLine, defValue: false),
                onChanged: (open) async {
                  await SpUtil.putBool(spShowLine, open);
                  setState(() {});
                },
              ),
              _switchRow(
                icon: CupertinoIcons.arrow_down_doc,
                title: "日志内容自动滚动",
                value: SpUtil.getBool(spLogAutoJump2Bottom, defValue: false),
                onChanged: (open) async {
                  await SpUtil.putBool(spLogAutoJump2Bottom, open);
                  setState(() {});
                },
              ),
              _switchRow(
                icon: CupertinoIcons.smiley,
                title: "使用Face ID解锁",
                value: SpUtil.getBool(spOpenAuth, defValue: false),
                onChanged: (open) async {
                  await SpUtil.putBool(spOpenAuth, open);
                  setState(() {});
                },
              ),
              _switchRow(
                icon: CupertinoIcons.wand_stars_inverse,
                title: "单实例模式",
                titleSuffix: _singleInstanceHelp(),
                value: SpUtil.getBool(spSingleInstance, defValue: false),
                onChanged: (open) async {
                  await SpUtil.putBool(spSingleInstance, open);
                  setState(() {});
                },
              ),
            ]),
            // 只在手动指定版本时才有意义，整块不渲染（不要留空标题）
            if (manualVersion) ...[
              const SizedBox(height: 12),
              _card(c, [
                _navRow(
                  icon: CupertinoIcons.paperplane,
                  title: "变更服务器版本号",
                  value: "(${systemBean.version})",
                  onTap: () => _updateVersion(context),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            _card(c, [
              _actionRow(
                icon: CupertinoIcons.square_arrow_right,
                title: "退出登录",
                onTap: _confirmLogout,
              ),
              _actionRow(
                icon: CupertinoIcons.trash,
                title: "退出登录并清空本地数据",
                onTap: _confirmLogoutAndClear,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// 单实例模式的说明气泡
  Widget _singleInstanceHelp() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showCupertinoDialog(
          useRootNavigator: false,
          context: context,
          builder: (context1) => CupertinoAlertDialog(
            content: const Text(
                "开启后可关闭多容器同时在线功能，减少APP对系统内存的消耗，通过长按首页 我的 切换账号"),
            title: const Text("温馨提示"),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  "确定",
                  style: TextStyle(color: ref.watch(themeProvider).primaryColor),
                ),
                onPressed: () {
                  Navigator.of(context1).pop();
                },
              ),
            ],
          ),
        );
      },
      child: const Icon(
        CupertinoIcons.question_circle,
        size: 16,
        color: Colors.grey,
      ),
    );
  }

  void _confirmLogout() {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("确认退出登录吗?"),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "取消",
              style: TextStyle(color: Color(0xff999999)),
            ),
            onPressed: () {
              Navigator.of(context1).pop();
            },
          ),
          CupertinoDialogAction(
            child: Text(
              "确定",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () {
              Navigator.of(context1).pop();
              SingleAccountPageState.ofUserInfo(context).updateToken(
                SingleAccountPageState.of(context)?.index ?? 0,
                SingleAccountPageState.ofUserInfo(context).host,
                "",
                false,
                SingleAccountPageState.ofUserInfo(context).alias,
              );
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.routeLogin,
                (p) {
                  return false;
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmLogoutAndClear() {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("确认退出登录并清空账号本地数据吗?"),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "取消",
              style: TextStyle(color: Color(0xff999999)),
            ),
            onPressed: () {
              Navigator.of(context1).pop();
            },
          ),
          CupertinoDialogAction(
            child: Text(
              "确定",
              style: TextStyle(color: ref.watch(themeProvider).primaryColor),
            ),
            onPressed: () {
              Navigator.of(context1).pop();
              clearData(context);
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.routeLogin,
                (p) {
                  return false;
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void clearData(BuildContext context) {
    getIt<MultiAccountUserInfoViewModel>()
        .removeHistoryAccount(SingleAccountPageState.ofUserInfo(context).host);
    SingleAccountPageState.ofUserInfo(context)
        .clearCurrentInfo(SingleAccountPageState.of(context)?.index ?? 0);
  }

  void _updateVersion(BuildContext context) async {
    String? host = SingleAccountPageState.ofUserInfo(context).host;

    TextEditingController controller = TextEditingController(
        text: getIt<SystemBean>(
                instanceName:
                    (SingleAccountPageState.of(context)?.index ?? 0).toString())
            .version);
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context1) => CupertinoAlertDialog(
        title: const Text("请输入版本号:"),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              child: TextField(
                textAlign: TextAlign.center,
                controller: controller,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: "请输入版本号",
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ref.watch(themeProvider).themeColor.title2Color(),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ref.watch(themeProvider).themeColor.title2Color(),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
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
              Navigator.of(context1).pop();
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
              Navigator.of(context1).pop();
              HomePageState.updateVersionHistory(VersionHistoryBean(
                  host: host, version: controller.text.trim()));
              SingleAccountPageState.of(context)
                  ?.registerSystemBean(controller.text.trim(), false);
              setState(() {});
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
}
