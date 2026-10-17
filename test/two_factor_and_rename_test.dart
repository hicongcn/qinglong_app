// 两步验证与脚本重命名的护栏。
//
// 2FA 这部分只测数据层（密钥解析与分组）—— 真实流程要连服务端拿 TOTP，
// 单测不碰。UI 入口用文本断言，与项目里其他护栏保持一致。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/module/login/two_factor_init_bean.dart';

void main() {
  group('两步验证初始化结果', () {
    test('解析 secret 与 otpauth url', () {
      final TwoFactorInitBean b = TwoFactorInitBean.fromJson(<String, dynamic>{
        "secret": "JBSWY3DPEHPK3PXP",
        "url": "otpauth://totp/qinglong:admin?secret=JBSWY3DPEHPK3PXP&issuer=qinglong",
      });
      expect(b.secret, "JBSWY3DPEHPK3PXP");
      expect(b.url, startsWith("otpauth://"));
    });

    test('密钥按 4 位分组，方便在认证器里手动输入', () {
      final TwoFactorInitBean b =
          TwoFactorInitBean.fromJson(<String, dynamic>{"secret": "JBSWY3DPEHPK3PXP"});
      expect(b.formattedSecret, "JBSW Y3DP EHPK 3PXP");
    });

    test('没有密钥时返回空串，不抛异常', () {
      expect(TwoFactorInitBean.fromJson(<String, dynamic>{}).formattedSecret, "");
    });
  });

  test('设置页有「两步验证」入口', () {
    final String setting = File('lib/module/setting_page.dart').readAsStringSync();
    expect(setting.contains('TwoFactorPage'), isTrue,
        reason: '设置页没有两步验证入口，用户无法开启/关闭');
    expect(setting.contains('两步验证'), isTrue);
  });

  test('脚本详情页有「重命名」入口且真的调了接口', () {
    final String page =
        File('lib/module/others/scripts/script_detail_page.dart').readAsStringSync();
    expect(page.contains('重命名'), isTrue, reason: '菜单里没有重命名');
    expect(page.contains('renameScript'), isTrue,
        reason: '只有文案没有调用 renameScript，等于没做');
  });

  test('两步验证三个接口都已接上', () {
    final String api = File('lib/base/http/api.dart').readAsStringSync();
    expect(api.contains('twoFactorInit'), isTrue);
    expect(api.contains('twoFactorActive'), isTrue);
    expect(api.contains('twoFactorDeactivate'), isTrue);
  });
}
