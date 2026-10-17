import 'dart:io';

import 'package:flutter/services.dart';

/// 取 iCloud 容器目录（iOS 专用）。
///
/// 备份文件必须落在 **iCloud Drive 的 ubiquity container** 里才有意义 ——
/// 存在 App 沙盒的 Documents 里，卸载重装就没了，那只是"本地备份"。
/// Dart 层拿不到容器 URL，所以走原生通道 `qinglong/icloud`
/// （实现在 `ios/Runner/AppDelegate.swift` 的 `setupICloudChannel`）。
///
/// ⚠️ 未签名 / 自签的包（TrollStore、AltStore、证书重签）通常**没有**有效的
/// iCloud entitlement，`url(forUbiquityContainerIdentifier:)` 会返回 nil。
/// 那是系统限制，不是代码问题 —— 这种情况下 [containerPath] 返回 null，
/// 上层自动降级成沙盒内备份。
class ICloudChannel {
  static const MethodChannel _channel = MethodChannel("qinglong/icloud");

  static String? _cachedPath;
  static bool _probed = false;

  /// 容器内的 `Documents` 绝对路径；不可用时返回 null。
  ///
  /// [refresh] 为 true 时重新探测（例如用户刚在系统设置里打开了 iCloud）。
  static Future<String?> containerPath({bool refresh = false}) async {
    if (!Platform.isIOS) return null;
    if (_probed && !refresh) return _cachedPath;

    try {
      _cachedPath = await _channel.invokeMethod<String>("containerPath");
    } on MissingPluginException {
      // 老包 / 没走场景路径启动时通道不存在
      _cachedPath = null;
    } on PlatformException {
      _cachedPath = null;
    } catch (_) {
      _cachedPath = null;
    }
    _probed = true;
    return _cachedPath;
  }

  /// iCloud 是否可用（探测失败一律当不可用，走本地）
  static Future<bool> available({bool refresh = false}) async {
    return (await containerPath(refresh: refresh)) != null;
  }
}
