import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/others/dashboard/dashboard_overview_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 运行概览（数据来自 `GET /api/dashboard/overview`）。
///
/// 刻意做成**一屏四个数字 + 两行小字**，不做图表：
/// 用户要的是"抬头看一眼今天跑了多少、挂了多少"，不是报表。
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DashboardOverviewBean? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    // 需要拿到 SingleAccountPageState 的 context，放到首帧之后
    WidgetsBinding.instance.addPostFrameCallback((_) => loadData());
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    final HttpResponse<DashboardOverviewBean> res =
        await SingleAccountPageState.ofApi(context).dashboardOverview();
    if (!mounted) return;
    setState(() {
      loading = false;
      if (res.success && res.bean != null) {
        data = res.bean;
      } else {
        error = res.message ?? "获取失败";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors themeColor = ref.watch(themeProvider).themeColor;
    return Scaffold(
      backgroundColor: themeColor.settingBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () => Navigator.of(context).pop(),
        title: "运行概览",
      ),
      body: SafeArea(top: false, child: _body(themeColor)),
    );
  }

  Widget _body(ThemeColors themeColor) {
    if (loading) {
      return const Center(child: LoadingWidget());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: themeColor.descColor()),
              ),
              const SizedBox(height: 14),
              CupertinoButton(
                color: ref.watch(themeProvider).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                onPressed: loadData,
                child: const Text("重试", style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    final DashboardOverviewBean d = data ?? DashboardOverviewBean();
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Row(
            children: [
              _card(themeColor, "任务总数", "${d.total ?? 0}", "启用 ${d.enabled ?? 0} · 禁用 ${d.disabled ?? 0}"),
              const SizedBox(width: 12),
              _card(themeColor, "今日运行", "${d.todayRuns ?? 0}", "成功 ${d.todaySuccess ?? 0} · 失败 ${d.todayFail ?? 0}"),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _card(themeColor, "成功率", "${d.successRate ?? "0"}%", "按今日运行统计"),
              const SizedBox(width: 12),
              _card(themeColor, "平均耗时", "${d.avgTime ?? 0} 秒", "今日每次运行"),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "数据来自面板的 dashboard 统计，下拉可刷新。",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: themeColor.hintColor()),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeColors themeColor, String title, String value, String hint) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        decoration: BoxDecoration(
          color: themeColor.settingBordorColor(),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, color: themeColor.descColor())),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: themeColor.titleColor(),
              ),
            ),
            const SizedBox(height: 6),
            Text(hint, style: TextStyle(fontSize: 11, color: themeColor.hintColor())),
          ],
        ),
      ),
    );
  }
}
