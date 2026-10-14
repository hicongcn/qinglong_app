import 'dart:async';
import 'dart:ui';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../../base/commit_button.dart';

class InTimeSubscribeLogPage extends StatefulWidget {
  final int cronId;
  final bool needTimer;
  final String title;

  const InTimeSubscribeLogPage(this.cronId, this.needTimer, this.title, {Key? key}) : super(key: key);

  @override
  _InTimeSubscribeLogPageState createState() => _InTimeSubscribeLogPageState();
}

class _InTimeSubscribeLogPageState extends State<InTimeSubscribeLogPage> with LazyLoadState<InTimeSubscribeLogPage>, WidgetsBindingObserver {
  Timer? _timer;

  String? content;

  ScrollController? controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // 观察前后台切换，用于暂停日志轮询
    WidgetsBinding.instance.addObserver(this);
    getLogData();
  }

  bool alwaysAuthScroll = false;

  bool isRequest = false;
  bool canRequest = true;

  /// 当前是否停在底部。必须在**替换内容之前**判断 —— 替换后
  /// maxScrollExtent 就变了，判断会失真。
  bool _isAtBottom() {
    final ScrollController? c = controller;
    if (c == null || !c.hasClients) return true;
    final ScrollPosition p = c.position;
    if (!p.hasContentDimensions) return true;
    return p.pixels >= p.maxScrollExtent - 24;
  }


  getLogData() async {
    if (!canRequest) return;
    if (isRequest) return;
    isRequest = true;
    HttpResponse<String> response = await SingleAccountPageState.ofApi(context).inTimeSubscribeLog(widget.cronId);
    if (response.success) {
      final bool wasAtBottom = _isAtBottom();
      content = response.bean;
      // 只有「用户本来就在底部」且开了跟随时才自动滚到底。
      // 用户滚上去看历史时别把他拽走 —— 那正是「页面自己动了」的来源。
      if (alwaysAuthScroll && wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          if ((controller?.hasClients ?? false)) {
            controller!.jumpTo(controller!.position.maxScrollExtent);
          }
        });
      }
      setState(() {});
    }
    isRequest = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  /// 退到后台/被其他页面覆盖时停止 2 秒一次的日志轮询（否则会一直拉取，
  /// 白白消耗流量与电量），回到前台再自动恢复。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!widget.needTimer) return;
    if (state == AppLifecycleState.resumed) {
      if (_timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
          getLogData();
        });
        getLogData();
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      return Scaffold(
        floatingActionButton: FloatingActionButton(
          mini: true,
          onPressed: () {
            setState(() {
              alwaysAuthScroll = !alwaysAuthScroll;
            });
          },
          elevation: 2,
          child: Icon(
            alwaysAuthScroll ? CupertinoIcons.pause_circle : CupertinoIcons.play_circle,
          ),
        ),
        appBar: QlAppBar(
          canBack: true,
          actions: [
            CommitButton(
              title: "分享",
              onTap: () {
                Share.share(content ?? "");
              },
            ),
          ],
          title: widget.title,
        ),
        body: SafeArea(
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.only(
              bottom: 10,
            ),
            child: (content == null)
                ? const Center(
                    child: LoadingWidget(),
                  )
                : CupertinoScrollbar(
                    child: SingleChildScrollView(
                      controller: controller,
                      primary: true,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: ExtendedText(
                        content!,
                        selectionHeightStyle: BoxHeightStyle.max,
                        selectionEnabled: true,
                        selectionWidthStyle: BoxWidthStyle.max,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    });
  }

  @override
  void onLazyLoad() {
    // 读出来的值要同步到 UI，否则 FAB 图标会显示「未开启」而实际跟随是开着的
    final bool saved = SpUtil.getBool(spLogAutoJump2Bottom, defValue: false);
    if (saved != alwaysAuthScroll) {
      alwaysAuthScroll = saved;
      if (mounted) setState(() {});
    }
    if (widget.needTimer) {
      // 先取消可能已存在的定时器：若页面是在「回到前台」回调之后才首次加载，
      // 生命周期回调可能已经建过一个定时器，直接覆盖会让旧定时器失去引用继续跑
      // （变成双倍轮询，白耗流量与电量）。
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (timer) {
          getLogData();
        },
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        getLogData();
      });
    }
  }
}
