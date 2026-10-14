import 'dart:async';
import 'dart:ui';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// 展示文本上限（约 80 万字符）。超长日志每次追加都要**整体重新排版**，
  /// 故只保留最近这一段；要全文可以用右上角「分享」导出。
  ///
  /// 关键：**只在用户正看着底部时才裁掉头部**（见 [_trim]）。用户正在上面翻看
  /// 历史时裁剪头部，会让视口里的内容整体上移 —— 表现就是「页面自己动了」。
  static const int _maxDisplayChars = 800000;

  /// 硬上限：超过它无论用户在看哪里都必须裁，否则排版开销与内存会失控。
  static const int _hardMaxDisplayChars = 2000000;

  /// 用户最近一次「手指拖动」滚动的时刻。用来区分「用户主动滚动」与
  /// 「内容变化 / 框架引起的位移」，后者要被 [_pinOffset] 纠正回去。
  DateTime? _lastUserScrollAt;

  /// 用户本次会话内是否亲手滚过。
  ///
  /// 一旦滚过，就**永久停止自动跟随**（而不是等他重新滚回底部又开始跟随）——
  /// 用户的原话是「我在看这段日志，别让它自己动」。想恢复跟随就点右下角按钮。
  bool _userTookOver = false;

  /// [_pinOffset] 的延迟复核定时器
  Timer? _pinTimer;

  bool get _userScrollingRecently =>
      _lastUserScrollAt != null &&
      DateTime.now().difference(_lastUserScrollAt!) < const Duration(milliseconds: 500);

  /// 轮询间隔。保持 2 秒 —— 每次只取新增的几十~几千字节，所以即便间隔不变，
  /// 观感也从「整段替换」变成「连续追加」，而且不会像 1 秒那样刷得过勤。
  static const Duration _pollInterval = Duration(seconds: 2);

  /// 超长时裁掉头部。`allowTrim=false`（用户正在翻看历史）时只受硬上限约束，
  /// 保证视口里的内容不会因为裁剪而移动。
  String _trim(String text, {required bool allowTrim}) {
    final int limit = allowTrim ? _maxDisplayChars : _hardMaxDisplayChars;
    if (text.length <= limit) return text;
    final int cut = text.length - limit;
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

  double? _offsetOf() {
    final ScrollController? c = controller;
    if (c == null || !c.hasClients) return null;
    final ScrollPosition p = c.position;
    if (!p.hasContentDimensions) return null;
    return p.pixels;
  }

  /// 未开启跟随时把视口钉在原处。
  ///
  /// 正常情况下内容增长**不会**移动视口（ScrollPosition 的 pixels 保持不动、
  /// 新内容接在下面），但文本重排、滚动条、选择区 bringIntoView 等边缘情况
  /// 有可能让它漂移 —— 一旦漂移，用户正在看的那段日志就被顶走了。
  ///
  /// 这里做一层兜底：只在用户没有主动滚动时，把 pixels 恢复回去。
  /// 检查两次（提交后的那一帧 + 150ms 后），因为有些位移发生在下一帧。
  void _pinOffset(double? before) {
    if (before == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pinOnce(before));
    _pinTimer?.cancel();
    _pinTimer = Timer(const Duration(milliseconds: 150), () => _pinOnce(before));
  }

  void _pinOnce(double before) {
    if (!mounted) return;
    if (alwaysAuthScroll) return;
    if (_userScrollingRecently) return;
    final ScrollController? c = controller;
    if (c == null || !c.hasClients) return;
    final ScrollPosition p = c.position;
    if (!p.hasContentDimensions) return;
    final double target = before.clamp(0.0, p.maxScrollExtent);
    if ((p.pixels - target).abs() > 0.5) {
      c.jumpTo(target);
    }
  }

  /// 平滑跟到底部。原来每次轮询都无条件 200ms 线性 animateTo，
  /// 配合 2 秒间隔就是「一顿一顿」；现在只在真有新内容、且用户本来就在底部时触发。
  void _scrollToBottom() {
    if (_userTookOver) return;
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
    final double? offsetBefore = _offsetOf();

    final String raw = chunk.content;
    final String next = fullFetch ? raw : ((content ?? "") + raw);
    if (fullFetch) _firstLoaded = true;
    _supportIncremental = chunk.supportIncremental;
    if (chunk.nextOffset != null) _nextOffset = chunk.nextOffset!;

    final bool changed = !hadLoaded || next != (content ?? "");
    // 用户在看底部时允许裁掉头部（他看不到），否则只受硬上限约束
    content = _trim(next, allowTrim: wasAtBottom || fullFetch);

    // 没有新内容就什么都不做 —— 不再空 setState、不再空滚一次
    if (!changed) return;

    setState(() {});

    unawaited(_maybeAutoInstallDep(raw));

    if (alwaysAuthScroll && wasAtBottom) {
      // 用户开了跟随、且本来就在底部：平滑跟到最新
      _scrollToBottom();
    } else if (!wasAtBottom) {
      // 用户正在翻看历史：把视口钉住，任何非用户引起的位移都恢复回去
      _pinOffset(offsetBefore);
    }
  }

  bool hasToastedFailed = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pinTimer?.cancel();
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
              if (alwaysAuthScroll) {
                // 用户明确要求跟随，清掉「已接管」状态
                _userTookOver = false;
              }
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
                : NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification n) {
                      // 只认「手指拖动」引起的更新：既用于区分用户滚动与内容变化，
                      // 也用于判断「用户已经自己接管了滚动」
                      if (n is ScrollUpdateNotification && n.dragDetails != null) {
                        _lastUserScrollAt = DateTime.now();
                        _userTookOver = true;
                      }
                      return false;
                    },
                    child: CupertinoScrollbar(
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
        ),
      );
    });
  }

  @override
  void onLazyLoad() {
    // 读出来的值必须同步到 UI：否则 FAB 图标会一直显示「未开启」，
    // 而实际跟随是开着的 —— 用户会以为「我没点它，页面却自己滚」。
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

