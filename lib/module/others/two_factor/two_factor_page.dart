import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/login/two_factor_init_bean.dart';
import 'package:qinglong_app/module/login/user_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 两步验证的开关管理。
///
/// 客户端原本只能"用" 2FA（登录时输验证码），没法开启或关闭。
/// 服务端流程（`back/services/user.ts:401-429`）：
/// 1. `GET  /user/two-factor/init` → 拿到 secret（**已启用时会报错**）
/// 2. `PUT  /user/two-factor/active` body `{code}` → 校验 TOTP，返回 boolean
/// 3. `PUT  /user/two-factor/deactivate` → 直接关闭，无需二次确认
///
/// ⚠️ 激活成功后服务端会清空所有 token，所以这里必须提示"重新登录"。
class TwoFactorPage extends ConsumerStatefulWidget {
  const TwoFactorPage({Key? key}) : super(key: key);

  @override
  _TwoFactorPageState createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends ConsumerState<TwoFactorPage> {
  bool loading = true;
  bool activated = false;
  bool submitting = false;

  /// 启用流程中的密钥信息；为 null 表示还没点"启用"
  TwoFactorInitBean? initInfo;

  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadStatus());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> loadStatus() async {
    if (!mounted) return;
    setState(() => loading = true);
    final HttpResponse<UserBean> res =
        await SingleAccountPageState.ofApi(context).user();
    if (!mounted) return;
    setState(() {
      loading = false;
      if (res.success && res.bean != null) {
        activated = res.bean!.twoFactorActivated == true;
      }
    });
  }

  Future<void> startEnable() async {
    final HttpResponse<TwoFactorInitBean> res =
        await SingleAccountPageState.ofApi(context).twoFactorInit();
    if (!mounted) return;
    if (res.success && res.bean != null) {
      setState(() => initInfo = res.bean);
    } else {
      (res.message ?? "生成密钥失败").toast();
    }
  }

  Future<void> confirmEnable() async {
    final String code = _codeController.text.trim();
    if (code.length < 6) {
      "请输入 6 位验证码".toast();
      return;
    }
    setState(() => submitting = true);
    final HttpResponse<String> res =
        await SingleAccountPageState.ofApi(context).twoFactorActive(code);
    if (!mounted) return;
    setState(() => submitting = false);

    // 服务端 data 是 boolean，Http 层会把它 jsonEncode 成 "true"/"false"
    if (res.success && res.bean == "true") {
      "已启用两步验证，请用验证码重新登录".toast();
      Navigator.of(context).pop(true);
    } else {
      "验证码不正确".toast();
    }
  }

  Future<void> deactivate() async {
    HapticFeedback.mediumImpact();
    final bool? ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("关闭两步验证"),
        content: const Text("关闭后登录只需要账号密码，不再校验验证码。"),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消", style: TextStyle(color: Color(0xff999999))),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            child: const Text("关闭"),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final HttpResponse<NullResponse> res =
        await SingleAccountPageState.ofApi(context).twoFactorDeactivate();
    if (!mounted) return;
    if (res.success) {
      "已关闭两步验证".toast();
      setState(() {
        activated = false;
        initInfo = null;
        _codeController.clear();
      });
    } else {
      (res.message ?? "关闭失败").toast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors themeColor = ref.watch(themeProvider).themeColor;
    return Scaffold(
      backgroundColor: themeColor.settingBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () => Navigator.of(context).pop(),
        title: "两步验证",
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: LoadingWidget())
            : ListView(
                padding: const EdgeInsets.all(15),
                children: [
                  Text(
                    activated
                        ? "已启用。登录时需要输入认证器里的 6 位验证码。"
                        : "未启用。启用后登录需要额外输入认证器生成的 6 位验证码。",
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: themeColor.descColor(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (activated) _buildEnabled(themeColor),
                  if (!activated && initInfo == null) _buildIdle(),
                  if (!activated && initInfo != null) _buildSetup(themeColor),
                ],
              ),
      ),
    );
  }

  /// 整行宽的按钮。CupertinoButton 默认按内容宽度收缩，
  /// 只给 color + padding 的话会变成一个贴着文字的小药丸（文字还会贴左边），
  /// 所以统一用 SizedBox 撑满 + 居中文字。
  Widget _fullWidthButton({
    required String title,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        borderRadius: BorderRadius.circular(10),
        color: color,
        onPressed: onTap,
        child: Center(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return _fullWidthButton(
      title: "启用两步验证",
      color: ref.watch(themeProvider).primaryColor,
      onTap: startEnable,
    );
  }

  Widget _buildEnabled(ThemeColors themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.checkmark_shield_fill,
                size: 18, color: const Color(0xff4C8EA1)),
            const SizedBox(width: 6),
            Text("已开启", style: TextStyle(fontSize: 14, color: themeColor.titleColor())),
          ],
        ),
        const SizedBox(height: 16),
        _fullWidthButton(
          title: "关闭两步验证",
          color: const Color(0xffFB5858),
          onTap: deactivate,
        ),
      ],
    );
  }

  Widget _buildSetup(ThemeColors themeColor) {
    final String secret = initInfo?.formattedSecret ?? "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("1. 在认证器里添加账号",
            style: TextStyle(fontSize: 14, color: themeColor.titleColor())),
        const SizedBox(height: 6),
        Text(
          "Google Authenticator / 微软 Authenticator / 1Password 都可以，"
          "选择「手动输入密钥」，把下面这串填进去：",
          style: TextStyle(fontSize: 12, height: 1.5, color: themeColor.descColor()),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: initInfo?.secret ?? ""));
            "密钥已复制".toast();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: themeColor.settingBordorColor(),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Text(
              secret,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                letterSpacing: 1,
                color: themeColor.titleColor(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text("点一下可复制", style: TextStyle(fontSize: 11, color: themeColor.hintColor())),
        const SizedBox(height: 20),
        Text("2. 输入认证器显示的 6 位验证码",
            style: TextStyle(fontSize: 14, color: themeColor.titleColor())),
        const SizedBox(height: 10),
        CupertinoTextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          placeholder: "6 位验证码",
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        const SizedBox(height: 8),
        Text(
          "启用后所有已登录的设备都会被登出，需要用验证码重新登录。",
          style: TextStyle(fontSize: 11, height: 1.5, color: themeColor.hintColor()),
        ),
        const SizedBox(height: 16),
        _fullWidthButton(
          title: submitting ? "验证中..." : "确认启用",
          color: ref.watch(themeProvider).primaryColor,
          onTap: submitting ? null : confirmEnable,
        ),
      ],
    );
  }
}
