import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/module/others/dashboard/dashboard_overview_bean.dart';
import 'package:qinglong_app/module/others/dashboard/dashboard_stats_bean.dart';

/// 仪表盘（对齐面板 `/dashboard`）。
///
/// 面板那边有 7 个接口，这里取其中 5 个有用的：
///   overview  → 8 个数字
///   trend     → 近 7 日执行趋势
///   top-time  → 今日耗时 Top 5
///   top-count → 今日执行次数 Top 5
///   system    → 面板主机内存 / CPU / 运行时长
/// （`/runtime` 的"正在跑的任务列表"没做：任务页本来就实时显示运行状态。）
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DashboardOverviewBean? overview;
  List<DashboardTrendBean> trend = <DashboardTrendBean>[];
  List<DashboardTopBean> topTime = <DashboardTopBean>[];
  List<DashboardTopBean> topCount = <DashboardTopBean>[];
  DashboardSystemBean? system;

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

    final api = SingleAccountPageState.ofApi(context);
    final List<dynamic> results = await Future.wait(<Future<dynamic>>[
      api.dashboardOverview(),
      api.dashboardTrend(),
      api.dashboardTopTime(),
      api.dashboardTopCount(),
      api.dashboardSystem(),
    ]);
    if (!mounted) return;

    final HttpResponse<DashboardOverviewBean> ov =
        results[0] as HttpResponse<DashboardOverviewBean>;
    setState(() {
      loading = false;
      if (ov.success && ov.bean != null) {
        overview = ov.bean;
      } else {
        error = ov.message ?? "获取失败";
      }
      trend = (results[1] as HttpResponse<List<DashboardTrendBean>>).bean ?? [];
      topTime = (results[2] as HttpResponse<List<DashboardTopBean>>).bean ?? [];
      topCount = (results[3] as HttpResponse<List<DashboardTopBean>>).bean ?? [];
      system = (results[4] as HttpResponse<DashboardSystemBean>).bean;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeColors c = ref.watch(themeProvider).themeColor;

    return Scaffold(
      backgroundColor: c.settingBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () => Navigator.of(context).pop(),
        title: "仪表盘",
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: CupertinoActivityIndicator())
            : error != null
                ? _errorView(c)
                : RefreshIndicator(
                    onRefresh: loadData,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        _numbers(c),
                        _trendCard(c),
                        _topTimeCard(c),
                        _topCountCard(c),
                        _systemCard(c),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _errorView(ThemeColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error ?? "", style: TextStyle(color: c.descColor())),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: loadData,
            child: const Text("重试"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 数字区

  Widget _numbers(ThemeColors c) {
    final Color primary = ref.watch(themeProvider).primaryColor;
    final DashboardOverviewBean? d = overview;
    final List<List<Widget>> rows = <List<Widget>>[
      <Widget>[
        _stat(c, "总任务", "${d?.total ?? 0}", c.titleColor()),
        _stat(c, "已启用", "${d?.enabled ?? 0}", primary),
      ],
      <Widget>[
        _stat(c, "已禁用", "${d?.disabled ?? 0}", c.descColor()),
        _stat(c, "今日执行", "${d?.todayRuns ?? 0}", c.titleColor()),
      ],
      <Widget>[
        _stat(c, "今日成功", "${d?.todaySuccess ?? 0}", const Color(0xff089556)),
        _stat(c, "今日失败", "${d?.todayFail ?? 0}", const Color(0xffE5484D)),
      ],
      <Widget>[
        _stat(c, "成功率", "${d?.successRate ?? "0"}%", const Color(0xff089556)),
        _stat(c, "平均耗时", _secText(d?.avgTime), c.titleColor()),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: r[0]),
                      const SizedBox(width: 10),
                      Expanded(child: r[1]),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  String _secText(int? seconds) {
    if (seconds == null || seconds <= 0) return "-";
    if (seconds < 60) return "${seconds}s";
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return "$m 分 $s 秒";
  }

  Widget _stat(ThemeColors c, String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: c.settingBordorColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.descColor())),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 趋势

  Widget _trendCard(ThemeColors c) {
    final Color primary = ref.watch(themeProvider).primaryColor;
    int max = 0;
    for (final DashboardTrendBean t in trend) {
      final int v = t.total ?? 0;
      if (v > max) max = v;
    }

    return _card(
      c,
      "近 7 日趋势",
      trend.isEmpty
          ? _empty(c, "暂无数据")
          : Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trend.map((t) {
                  final int total = t.total ?? 0;
                  final int fail = t.fail ?? 0;
                  final double h = max == 0 ? 0 : (total / max) * 84;
                  return Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total == 0 ? "" : "$total",
                          style: TextStyle(fontSize: 10, color: c.descColor()),
                        ),
                        const SizedBox(height: 2),
                        // 柱体高度 = 总执行次数；有失败时柱内压一段红色
                        Container(
                          height: h < 2 ? 2 : h,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: total == 0
                                ? c.descColor().withOpacity(0.15)
                                : primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: fail > 0 && total > 0
                              ? FractionallySizedBox(
                                  heightFactor: (fail / total).clamp(0.15, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xffE5484D),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.shortDate,
                          maxLines: 1,
                          style: TextStyle(fontSize: 9, color: c.descColor()),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------- Top 榜

  Widget _topTimeCard(ThemeColors c) {
    return _card(
      c,
      "今日耗时 Top 5",
      topTime.isEmpty
          ? _empty(c, "今天还没有执行记录")
          : Column(
              children: topTime
                  .map((t) => _rankRow(
                        c,
                        t.name ?? "-",
                        "${t.timeText(t.avgTime)} / 最长 ${t.timeText(t.maxTime)}",
                      ))
                  .toList(),
            ),
    );
  }

  Widget _topCountCard(ThemeColors c) {
    return _card(
      c,
      "今日执行次数 Top 5",
      topCount.isEmpty
          ? _empty(c, "今天还没有执行记录")
          : Column(
              children: topCount
                  .map((t) => _rankRow(c, t.name ?? "-", "${t.runCount ?? 0} 次"))
                  .toList(),
            ),
    );
  }

  Widget _rankRow(ThemeColors c, String name, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: c.titleColor()),
            ),
          ),
          const SizedBox(width: 10),
          Text(value, style: TextStyle(fontSize: 12, color: c.descColor())),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 面板状态

  Widget _systemCard(ThemeColors c) {
    final Color primary = ref.watch(themeProvider).primaryColor;
    final DashboardSystemBean? s = system;

    return _card(
      c,
      "面板状态",
      s == null
          ? _empty(c, "暂无数据")
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("内存占用",
                        style: TextStyle(fontSize: 13, color: c.titleColor())),
                    const Spacer(),
                    Text(
                      "${s.memUsagePercent ?? "-"}%",
                      style: TextStyle(fontSize: 13, color: c.descColor()),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.memPercentValue,
                    minHeight: 6,
                    backgroundColor: c.descColor().withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(height: 12),
                _kv(c, "Node 堆",
                    "${s.heapUsed ?? "-"} / ${s.heapTotal ?? "-"} MB"),
                _kv(c, "CPU 核数", "${s.cpus ?? "-"}"),
                _kv(c, "运行时长", s.uptimeText),
                _kv(c, "平台", s.platform ?? "-"),
              ],
            ),
    );
  }

  Widget _kv(ThemeColors c, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(k, style: TextStyle(fontSize: 13, color: c.titleColor())),
          const Spacer(),
          Text(v, style: TextStyle(fontSize: 13, color: c.descColor())),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 版式

  Widget _card(ThemeColors c, String title, Widget child) {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.settingBordorColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.titleColor(),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _empty(ThemeColors c, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(text, style: TextStyle(fontSize: 13, color: c.descColor())),
      ),
    );
  }
}
