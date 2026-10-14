import 'dart:convert';
import 'dart:io';

import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import 'sp_const.dart';
import 'userinfo_viewmodel.dart';

class MultiAccountUserInfoViewModel {
  /// 多账号上限。原实现按 VIP 等级分级（普通 1 / VIP 3 / SVIP 5），
  /// 现已取消 VIP 体系，统一放开到 5，用户可在「多账号数」里自行调整。
  static int maxAccount = 5;

  List<TokenBean> tokenBeans = [];
  List<UserInfoBean> historyAccounts = [];

  static void updateMaxAccount(int count) {

    SpUtil.putInt(spAccountCount, count);
  }

  MultiAccountUserInfoViewModel() {
    try {
      List<dynamic>? tempTokenList = jsonDecode(SpUtil.getString(spTokenBeanList, defValue: '[]'));

      if (tempTokenList != null && tempTokenList.isNotEmpty) {
        for (Map<String, dynamic> value in tempTokenList) {
          //把token里的空数据拿掉
          var bean = TokenBean.fromJson(value);
          if (bean.host == null && bean.token == null) continue;
          tokenBeans.add(TokenBean.fromJson(value));
        }
      }

      List<dynamic>? tempList = jsonDecode(SpUtil.getString(spLoginHistory, defValue: '[]'));

      if (tempList != null && tempList.isNotEmpty) {
        for (Map<String, dynamic> value in tempList) {
          historyAccounts.add(UserInfoBean.fromJson(value));
        }
      }
    } catch (e) {
      e.toString().toast2();
    }
  }

  /// 初始化多账号上限（不再区分 VIP 等级）。
  void initVipState() {
    maxAccount = SpUtil.getInt(spAccountCount, defValue: 5);
    if (maxAccount < 1) maxAccount = 1;
  }

  void save2HistoryAccount(UserInfoBean userInfoBean) {
    //如果已经存在host，那就更新

    historyAccounts.removeWhere((element) => element.host == userInfoBean.host);

    historyAccounts.insert(
      0,
      userInfoBean,
    );

    SpUtil.putString(spLoginHistory, jsonEncode(historyAccounts));
  }

  void removeHistoryAccount(String? host) {
    if (host == null || host.isEmpty) return;

    historyAccounts.removeWhere((element) => element.host == host);

    SpUtil.putString(spLoginHistory, jsonEncode(historyAccounts));
  }

  void updateToken(int index, String? host, String? token, bool useSecretLogined, String? alias) {
    if (host == null) return;

    if (MultiAccountUserInfoViewModel.maxAccount == 1) {
      tokenBeans.clear();
      tokenBeans.add(
        TokenBean(
          token: token,
          host: host,
          useSecretLogined: useSecretLogined,
          alias: alias,
        ),
      );
    } else {
      if (tokenBeans.length <= index) {
        tokenBeans.add(
          TokenBean(
            token: token,
            host: host,
            useSecretLogined: useSecretLogined,
            alias: alias,
          ),
        );
      } else {
        tokenBeans[index].token = token;
        tokenBeans[index].useSecretLogined = useSecretLogined;
        tokenBeans[index].alias = alias;
        tokenBeans[index].host = host;
      }
    }
    SpUtil.putString(spTokenBeanList, jsonEncode(tokenBeans));
  }

  void removeTokenBean(int index) {
    tokenBeans[index].token = null;
    tokenBeans[index].host = null;
    tokenBeans[index].alias = null;
    tokenBeans[index].useSecretLogined = false;
    SpUtil.putString(spTokenBeanList, jsonEncode(tokenBeans));
  }

  void resetTokenBeans(List<TokenBean> bean) {
    SpUtil.putString(spTokenBeanList, jsonEncode(bean));
    tokenBeans.clear();
    tokenBeans.addAll(bean);
  }
}
