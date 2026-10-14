import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// VIP 体系已彻底移除（用户要求「都开放」），本测试用来防止它被重新引入：
///   1) 源码里不得再出现 VIP 相关标识与内购页；
///   2) 多账号上限不再按等级分级，默认放开到 5，并仍可由用户自定义。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 这些标识一旦重新出现，说明 VIP 门禁又回来了
  const List<String> forbiddenTokens = <String>[
    'spVIP',
    'typeVIP',
    'typeSVIP',
    'typeNormal',
    'InAppPurchasePage',
  ];

  test('源码中不再有任何 VIP 门禁标识', () {
    final List<String> hits = <String>[];
    for (final FileSystemEntity e
        in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final String src = e.readAsStringSync();
      for (final String token in forbiddenTokens) {
        if (src.contains(token)) {
          hits.add('${e.path}: $token');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason: 'VIP 体系已移除，不应再出现这些标识：\n${hits.join('\n')}',
    );
  });

  test('内购页与其资源已删除', () {
    expect(
      File('lib/module/in_app_purchase_page.dart').existsSync(),
      isFalse,
      reason: '内购页应当已删除（功能全部免费开放）',
    );
  });

  test('多账号上限：默认放开到 5，且仍可自定义', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();

    // 把静态值打到旧默认（1），确认 initVipState 不再把它按 VIP 压回 1
    MultiAccountUserInfoViewModel.maxAccount = 1;
    MultiAccountUserInfoViewModel().initVipState();
    expect(
      MultiAccountUserInfoViewModel.maxAccount,
      5,
      reason: '未设置过数量时应放开到 5（原 VIP/SVIP 上限），而不是普通用户的 1',
    );

    // 用户自定义的个数仍然生效
    await SpUtil.putInt(spAccountCount, 8);
    MultiAccountUserInfoViewModel().initVipState();
    expect(
      MultiAccountUserInfoViewModel.maxAccount,
      8,
      reason: '用户自己在「多账号数」里设置的个数应当生效',
    );
  });
}
