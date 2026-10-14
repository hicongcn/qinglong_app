import 'dart:async';
import 'dart:ui';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/scan_page.dart';
import 'package:qinglong_app/module/task/intime_log/intime_log_chunk.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../../base/commit_button.dart';
import '../../../base/http/api.dart';

class InTimeLogPage extends ConsumerStatefulWidget {
  final String cronId;
  final bool needTimer;
  final String title;
  final String? command;

  const InTimeLogPage(
    this.cronId,
    this.needTimer,
    this.title, {
    Key? key,
    this.command,
  }) : super(key: key);

  @override
  _InTimeLogPageState createState() => _InTimeLogPageState();
}

class _InTimeLogPageState extends ConsumerState<InTimeLogPage> with LazyLoadState<InTimeLogPage>, WidgetsBindingObserver {
  Timer? _timer;

  /// 已展示的完整日志文本；null 表示还没拿到首帧（显示 loading）
  String? content;

  bool isRequest = false;
  bool canRequest = true;
  bool alwaysAuthScroll = false;

  ScrollController? controller = ScrollController();

  /// 下次增量读取的起点（服务端的 nextOffset）
  int _nextOffset = 0;

  /// 是否已完成首帧（首帧走 tail 取文件尾部整段）
  bool _firstLoaded = false;

  /// 服务端是否支持增量读取；老服务端不返回 nextOffset 时退回整段刷新
  bool _supportIncremental = true;

  /// 展示文本上限（约 40 万字符）。超长日志每次追加都会**整体重新排版**，
  /// 这里只保留最近这一段；要全文可以用右上角「分享」导出。
  static const int _maxDisplayChars = 400000;

  /// 轮询间隔。增量读取每次只取新增的几十~几千字节，所以可以比原来（2 秒）
  /// 更勤，观感就接近流式追加而不是「每 2 秒跳一下」。
  static const Duration _pollInterval = Duration(seconds: 1);

  String _trim(String text) {
    if (text.length <= _maxDisplayChars) return text;
    final int cut = text.length - _maxDisplayChars;
    final int nl = text.indexOf('\n', cut);
    return text.substring(nl >= 0 ? nl + 1 : cut);
  }

  bool _isAtBottom() {
    final ScrollController? c = controller;
    if (c == null || !c.hasClients) return true;
    final ScrollPosition p = c.position;
    if (!p.hasContentDimensions) return true;
    return p.pixels >= p.maxScrollExtent - 24;
  }

  /// 平滑跟到底部。原来每次轮询都无条件 200ms 线性 animateTo，
  /// 配合 2 秒间隔就是「一顿一顿」；现在只在真有新内容、且用户本来就在底部时触发。
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ScrollController? c = controller;
      if (c == null || !c.hasClients) return;
      c.animateTo(
        c.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  /// 检测脚本缺依赖并自动安装。
  /// 原来每 2 秒对**全文**扫一遍；现在只扫新增文本 —— 更省，也更不会重复触发。
  Future<void> _maybeAutoInstallDep(String text) async {
    final String? command = widget.command;
    if (command == null || text.isEmpty) return;
    if (!command.endsWith(".js") && !command.endsWith(".ts") && !command.endsWith(".py")) {
      return;
    }
    final String? found = ScanPageState.foundReg(command, text);
    if (found == null || found.isEmpty) return;
    if (!mounted) return;
    final Api api = Api(SingleAccountPageState.of(context)?.index ?? 0);
    final result = await ScanPageState.autoInstallFounded(api, found, command);
    if (result == true && mounted) {
      "已安装依赖 $found".toast();
    }
  }

  Future<void> getLogData({bool reset = false}) async {
    if (!canRequest) return;
    if (isRequest) return;
    if (!mounted) return;
    isRequest = true;

    final bool hadLoaded = _firstLoaded;
    // 首帧、或服务端不支持增量时，都取「尾部整段」
    final bool fullFetch = reset || !_firstLoaded || !_supportIncremental;

    final InTimeLogChunk chunk = await SingleAccountPageState.ofApi(context).inTimeLogChunk(
      widget.cronId,
      tail: fullFetch,
      offset: fullFetch ? null : _nextOffset,
    );

    if (!mounted) return;
    isRequest = false;

    if (!chunk.success) {
      if (!hasToastedFailed) {
        hasToastedFailed = true;
        (chunk.message ?? "日志读取失败").toast();
      }
      return;
    }

    // 日志文件被轮转/清空：服务端会把 offset 夹到文件尾，于是 nextOffset 反而变小
    if (!fullFetch && chunk.nextOffset != null && chunk.nextOffset! < _nextOffset) {
      await getLogData(reset: true);
      return;
    }

    // 必须在追加**之前**取：追加后 maxScrollExtent 变了就判断不准了
    final bool wasAtBottom = _isAtBottom();

    final String raw = chunk.content;
    final String next = fullFetch ? raw : ((content ?? "") + raw);
    if (fullFetch) _firstLoaded = true;
    _supportIncremental = chunk.supportIncremental;
    if (chunk.nextOffset != null) _nextOffset = chunk.nextOffset!;

    final bool changed = !hadLoaded || next != (content ?? "");
    content = _trim(next);

    // 没有新内容就什么都不做 —— 不再空 setState、不再空滚一次
    if (!changed) return;

    setState(() {});

    unawaited(_maybeAutoInstallDep(raw));

    if (alwaysAuthScroll && wasAtBottom) {
      _scrollToBottom();
    }
  }

  bool hasToastedFailed = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
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
        _timer = Timer.periodic(_pollInterval, (timer) {
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
  void initState() {
    super.initState();
    // 观察前后台切换，用于暂停日志轮询
    WidgetsBinding.instance.addObserver(this);
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
            // 打开跟随时立刻到底，不必等下一次轮询
            if (alwaysAuthScroll) _scrollToBottom();
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
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
          ),
        ),
      );
    });
  }

  @override
  void onLazyLoad() {
    alwaysAuthScroll = SpUtil.getBool(spLogAutoJump2Bottom, defValue: false);
    if (widget.needTimer) {
      // 先取消可能已存在的定时器：若页面是在「回到前台」回调之后才首次加载，
      // 生命周期回调可能已经建过一个定时器，直接覆盖会让旧定时器失去引用继续跑
      // （变成双倍轮询，白耗流量与电量）。
      _timer?.cancel();
      _timer = Timer.periodic(
        _pollInterval,
        (timer) {
          getLogData();
        },
      );
      getLogData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        getLogData();
      });
    }
  }
}

