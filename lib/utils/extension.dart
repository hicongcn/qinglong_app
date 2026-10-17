import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';

extension ContextExt on BuildContext {
  T read<T>(ProviderBase<T> provider) {
    return ProviderScope.containerOf(this, listen: false).read(provider);
  }
}

extension StringExt on String? {
  void toast() {
    if (this == null || this!.isEmpty) return;
    Fluttertoast.showToast(
      msg: this!,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
    );
  }

  void toast2() {
    if (this == null || this!.isEmpty) return;
    Fluttertoast.showToast(
      msg: this!,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
    );
  }

  void log() {
    logger.i(this);
  }
}


/// 调用系统分享面板。
///
/// 两个坑必须一起处理，否则表现就是「点了没反应」：
///  1. **iPad / iOS 上必须给 `sharePositionOrigin`**，不给系统直接不弹面板（iPhone 不用）；
///  2. 内容还没加载完时传空串，部分系统会静默什么都不做 —— 这里先拦一下并提示。
///
/// 之前只有脚本详情页做了这两件事，日志页 / 配置文件页都是裸 `Share.share(content ?? "")`，
/// 用户反馈「分享无反应」就是这个原因。
void shareTextContent(
  BuildContext context,
  String? text, {
  String? subject,
}) {
  final String value = text ?? "";
  if (value.trim().isEmpty) {
    "内容还没加载完".toast();
    return;
  }
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  Share.share(
    value,
    subject: subject,
    sharePositionOrigin:
        box != null ? box.localToGlobal(Offset.zero) & box.size : null,
  );
}
