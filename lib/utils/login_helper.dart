import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/module/login/login_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../main.dart';

class LoginHelper {
  static int success = 0;
  static int failed = 1;
  static int twiceLogin = 2;

  /// 服务端尚未初始化（青龙首次部署）：登录接口返回 code 450 /「请先初始化」。
  /// 这种情况任何账号都登不上，需要引导用户先设置管理员账号密码。
  static int needInit = 3;

  final String host;
  final String userName;
  final String password;
  final String? alias;
  final bool rememberPassword;

  LoginHelper(
    this.host,
    this.userName,
    this.password,
    this.rememberPassword,
    this.alias,
  );

  Future<int> login(BuildContext context) async {
    SingleAccountPageState.ofHttp(context)?.clear();
    SingleAccountPageState.ofHttp(context)?.host = host;

    SingleAccountPageState.ofUserInfo(context).updateHost(host);
    HttpResponse<LoginBean> response;

    if (loginByUserName()) {
      response =
          await SingleAccountPageState.ofApi(context).login(userName, password);
    } else {
      response = await SingleAccountPageState.ofApi(context)
          .loginByClientId(userName, password);
    }
    if (response.success) {
      loginSuccess(context, response, userName, password);
      return success;
    } else if (response.code == 450) {
      // 450 = 服务端尚未初始化。不弹「请先初始化」这种没出路的提示，
      // 交给调用方弹出初始化对话框（见 initServer）。
      return needInit;
    } else {
      (response.message ?? "请检查网络情况").toast();
      //420代表需要2步验证
      if (response.code == 420) {
        return twiceLogin;
      } else {
        return failed;
      }
    }
  }

  Future<int> loginTwice(BuildContext context, String code) async {
    HttpResponse<LoginBean> response =
        await SingleAccountPageState.ofApi(context)
            .loginTwo(userName, password, code);
    if (response.success) {
      loginSuccess(context, response, userName, password);
      return success;
    } else {
      (response.message ?? "请检查网络情况").toast();
      return failed;
    }
  }

  void loginSuccess(BuildContext context, HttpResponse<LoginBean> response,
      String userName, String password) {
    SingleAccountPageState.ofUserInfo(context).updateToken(
        SingleAccountPageState.of(context)?.index ?? 0,
        host,
        response.bean?.token ?? "",
        false,
        alias);
    if (rememberPassword) {
      SingleAccountPageState.ofUserInfo(context)
          .updateUserName(host, userName, password, !loginByUserName(), alias);
    } else {
      SingleAccountPageState.ofUserInfo(context)
          .updateUserName(host, "", "", !loginByUserName(), alias);
    }
  }

  bool loginByUserName() {
    return true;
  }

  /// 服务端尚未初始化时的引导：就地设置管理员账号密码。
  /// 对应服务端 `PUT /api/user/init`（body: username / password）：
  /// 成功 200；已完成初始化返回 450；密码为 admin 返回 400。
  static Future<void> initServer(
    BuildContext context, {
    VoidCallback? onFinished,
  }) async {
    String userName = "";
    String password = "";

    final bool? submitted = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text("初始化服务端"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                "这个青龙服务端还没有账号（首次部署），请先设置管理员账号密码，设置完成后可直接登录。",
                style: TextStyle(fontSize: 13),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: TextField(
                onChanged: (value) => userName = value,
                maxLines: 1,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                  hintText: "账号",
                ),
                autofocus: true,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: TextField(
                onChanged: (value) => password = value,
                maxLines: 1,
                obscureText: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                  hintText: "密码（不能设为 admin）",
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "取消",
              style: TextStyle(color: Color(0xff999999)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          CupertinoDialogAction(
            child: const Text("确定"),
            onPressed: () async {
              if (userName.trim().isEmpty || password.isEmpty) {
                "请填写账号和密码".toast();
                return;
              }
              Navigator.of(dialogContext).pop(true);
              final HttpResponse<NullResponse> result =
                  await SingleAccountPageState.ofApi(context)
                      .initUser(userName.trim(), password);
              if (result.success) {
                "初始化成功，请点击登录".toast();
              } else if (result.code == 450) {
                "该服务端已完成初始化，请直接登录".toast();
              } else {
                (result.message ?? "初始化失败").toast();
              }
              onFinished?.call();
            },
          ),
        ],
      ),
    );

    if (submitted != true) {
      onFinished?.call();
    }
  }
}
