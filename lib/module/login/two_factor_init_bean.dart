import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 两步验证初始化结果（服务端 `GET /api/user/two-factor/init`）。
///
/// 服务端 `back/services/user.ts:401`：
/// ```js
/// const secret = authenticator.generateSecret();
/// const otpauth = authenticator.keyuri(username, 'qinglong', secret);
/// return { secret, url: otpauth };
/// ```
/// `url` 是 `otpauth://totp/...`，可以转成二维码；客户端没有二维码库，
/// 所以界面上直接展示 `secret`，让用户在认证器里选"手动输入密钥"。
@JsonConversion()
class TwoFactorInitBean {
  /// Base32 密钥
  String? secret;

  /// otpauth:// 链接（可复制，能直接导入认证器）
  String? url;

  TwoFactorInitBean({this.secret, this.url});

  TwoFactorInitBean.fromJson(Map<String, dynamic> json) {
    secret = json['secret'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['secret'] = secret;
    data['url'] = url;
    return data;
  }

  /// 每 4 位加空格，方便照着抄
  String get formattedSecret {
    final String raw = secret ?? "";
    if (raw.isEmpty) return "";
    final List<String> parts = <String>[];
    for (int i = 0; i < raw.length; i += 4) {
      parts.add(raw.substring(i, i + 4 > raw.length ? raw.length : i + 4));
    }
    return parts.join(" ");
  }

  static TwoFactorInitBean jsonConversion(Map<String, dynamic> json) {
    return TwoFactorInitBean.fromJson(json);
  }
}
