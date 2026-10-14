import 'package:flutter/cupertino.dart';
import 'package:qinglong_app/base/base_viewmodel.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_bean.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class ConfigViewModel extends BaseViewModel {
  List<ConfigBean> list = [];

  @override
  void retry(BuildContext context, {bool showLoading = true}) {
    loadData(context, showLoading);
  }

  Future<void> loadData(BuildContext context, [isLoading = true]) async {
    if (isLoading && list.isEmpty) {
      loading(notify: true);
    }

    HttpResponse<List<ConfigBean>> result =
        await SingleAccountPageState.ofApi(context).files();

    if (result.success && result.bean != null) {
      list.clear();
      list.addAll(result.bean!);
      backUpAllConfigFiles(context);
      success();
    } else {
      list.clear();
      failed(result.message, notify: true);
    }
  }

  /// 把全部配置文件同步到本地/iCloud 备份。
  ///
  /// 两处开销控制（原实现都没有，是「配置文件」页面卡顿的来源之一）：
  /// 1. 与 `ICloudUtils.asyncConfig` 的前置条件保持一致 —— 非 VIP、或关闭了
  ///    备份开关时直接返回。否则每次进入配置文件页都会把**全部**配置文件
  ///    逐个请求一遍（N 次串行 HTTP 往返），而这些请求最后的写入都会被
  ///    `asyncConfig` 自己丢弃，纯属白跑。
  /// 2. 确实需要备份时按批并发抓取，不再串行 await，配置文件多时总耗时可
  ///    压到原来的 1/4 左右。
  void backUpAllConfigFiles(BuildContext context) async {
    if (list.isEmpty) return;
    if (SpUtil.getInt(spVIP, defValue: typeNormal) == typeNormal) return;
    if (SpUtil.getBool(spICloud, defValue: true) == false) return;

    final api = SingleAccountPageState.ofApi(context);
    final icloudUtils = getIt<ICloudUtils>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString());

    const int batchSize = 4;
    for (int start = 0; start < list.length; start += batchSize) {
      final batch = list.sublist(
        start,
        (start + batchSize) > list.length ? list.length : (start + batchSize),
      );
      await Future.wait(batch.map((ConfigBean c) async {
        HttpResponse<String> result =
            await api.content(c.title ?? c.value ?? "");
        if (result.success && result.bean != null) {
          await icloudUtils.asyncConfig(c.title, result.bean ?? "");
        }
      }));
    }
  }
}
