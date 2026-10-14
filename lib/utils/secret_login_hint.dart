import 'package:flutter/widgets.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart';

/// 服务端的「应用密钥」登录模式（`/open/*`）只对 `AppScope` 里声明的模块开放，
/// 而青龙的 `AppScope` 并不包含 `subscriptions` / `dependencies`
/// —— 这两页在该登录模式下必然返回 401。
///
/// 这里把那种「没头没脑的 401」换成明确的解释与出路，避免用户以为是自己
/// 权限配错了或者客户端坏了。
String? secretLoginScopeHint(
  BuildContext context,
  int? code,
  String featureName,
) {
  if (code != 401) return null;

  try {
    final int index = SingleAccountPageState.of(context)?.index ?? 0;
    final UserInfoViewModel viewModel =
        getIt<UserInfoViewModel>(instanceName: index.toString());
    if (!viewModel.useSecretLogined) return null;
  } catch (_) {
    // 拿不到登录方式时保持原样提示
    return null;
  }

  return "当前为「应用密钥」登录，青龙未对该密钥开放「$featureName」权限，"
      "请改用账号密码登录该服务器";
}
