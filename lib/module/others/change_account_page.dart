import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../main.dart';

class ChangeAccountPage extends ConsumerStatefulWidget {
  const ChangeAccountPage({Key? key}) : super(key: key);

  @override
  _ChangeAccountPageState createState() => _ChangeAccountPageState();
}

class _ChangeAccountPageState extends ConsumerState<ChangeAccountPage> {
  @override
  void initState() {
    super.initState();

    FocusManager.instance.primaryFocus?.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (MultiAccountUserInfoViewModel.maxAccount == 1) {
        "请杀掉App重新进入,即可启用多账号切换功能".toast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int count = getIt<MultiAccountUserInfoViewModel>().tokenBeans.length + 1;
    if (count > MultiAccountUserInfoViewModel.maxAccount) {
      count = MultiAccountUserInfoViewModel.maxAccount;
    }
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: ref.watch(themeProvider).themeMode == modeDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: kToolbarHeight,
                      ),
                      child: Icon(
                        CupertinoIcons.clear_thick,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "轻触账号以切换身份使用",
                  style: TextStyle(
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                    fontSize: 22,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      bottom: 30,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      try {
                        final List<TokenBean> beans =
                            getIt<MultiAccountUserInfoViewModel>().tokenBeans;
                        if (index >= beans.length ||
                            (beans.length < count && index == count - 1)) {
                          return addAccount(context, index);
                        }

                        // ⚠️ 不要直接 getIt<UserInfoViewModel>(instanceName: index)：
                        // 该实例是「对应账号的 SingleAccountPage」在 initState 里注册的，
                        // 没被打开过的账号（多实例时很常见）根本没注册，直接取会抛
                        // ArgumentError，整个页面被 ErrorWidget 顶掉 —— 就是用户看到的
                        // 「报错了：请尝试右滑退出页面…」。所以列表数据一律取 TokenBean，
                        // 运行时对象取不到就降级成只读展示。
                        final TokenBean bean = beans[index];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            context
                                .findAncestorStateOfType<MultiAccountPageState>()
                                ?.updateIndex(index);
                            Navigator.of(
                              context,
                            ).pop();
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: ref
                                  .watch(themeProvider)
                                  .themeColor
                                  .settingBordorColor(),
                              child: buildCell(bean, index),
                            ),
                          ),
                        );
                      } catch (e) {
                        // 单条渲染失败也不要连累整页
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          child: Text(
                            "这条账号读取失败：$e",
                            style: const TextStyle(
                              color: Color(0xffFB5858),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                    },
                    separatorBuilder: (_, __) {
                      return Container(
                        color: ref.watch(themeProvider).themeColor.settingBgColor(),
                        child: const Divider(
                          height: 1,
                          indent: 15,
                        ),
                      );
                    },
                    itemCount: count,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 取运行时对象；没注册就返回 null（不抛异常）。
  UserInfoViewModel? tryUserInfo(int index) {
    try {
      return getIt<UserInfoViewModel>(instanceName: index.toString());
    } catch (e) {
      return null;
    }
  }

  Widget buildCell(TokenBean bean, int index) {
    final UserInfoViewModel? live = tryUserInfo(index);
    final String host = (bean.host ?? "").isNotEmpty ? bean.host! : (live?.host ?? "");
    final String alias = (bean.alias ?? "").isNotEmpty ? bean.alias! : (live?.alias ?? "");
    final String token = (bean.token ?? "").isNotEmpty ? bean.token! : (live?.token ?? "");

    Widget child = ListTile(
      title: Text(
        host,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        alias,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
      ),
      minVerticalPadding: 10,
      trailing: token.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: ref.watch(themeProvider).primaryColor, width: 1),
              ),
              child: Text(
                "已登录",
                style: TextStyle(color: ref.watch(themeProvider).primaryColor, fontSize: 12),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xffFB5858), width: 1),
              ),
              child: const Text(
                "未登录",
                style: TextStyle(color: Color(0xffFB5858), fontSize: 12),
              ),
            ),
    );
    if (host.isEmpty) {
      return child;
    }

    return Slidable(
        key: ValueKey("${host}_$index"),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: 0.2,
          children: [
            SlidableAction(
              backgroundColor: const Color(0xffEA4D3E),
              onPressed: (_) {
                if (token.isNotEmpty) {
                  "请先退出登录，再删除".toast();
                  return;
                }

                showCupertinoDialog(
                  context: context,
                  useRootNavigator: false,
                  builder: (childContext) => CupertinoAlertDialog(
                    title: const Text("温馨提示"),
                    content: const Text("确定删除吗?"),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text(
                          "取消",
                          style: TextStyle(
                            color: Color(0xff999999),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(childContext).pop();
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
                          Navigator.of(childContext).pop();
                          getIt<MultiAccountUserInfoViewModel>()
                              .removeHistoryAccount(host);
                          // 该账号的运行时对象可能压根没注册，取不到就只清本地记录
                          tryUserInfo(index)?.clearCurrentInfo(index);
                          setState(() {});
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
        child: child);
  }

  Widget addAccount(BuildContext context, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.findAncestorStateOfType<MultiAccountPageState>()?.updateIndex(index);
        Navigator.of(
          context,
        ).pop();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 15,
          ),
          decoration: BoxDecoration(
            color: ref.watch(themeProvider).themeColor.settingBordorColor(),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: ref.watch(themeProvider).themeColor.descColor(),
                  ),
                ),
                child: Icon(
                  CupertinoIcons.add,
                  color: ref.watch(themeProvider).themeColor.descColor(),
                ),
              ),
              const SizedBox(
                width: 15,
              ),
              Text(
                "添加账号",
                style: TextStyle(
                  color: ref.watch(themeProvider).themeColor.titleColor(),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
