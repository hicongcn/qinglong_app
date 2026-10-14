import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/src/consumer.dart';
import 'package:qinglong_app/main.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../base/theme.dart';
import 'impl.dart';

class CodeMirrorView extends CodeMirrorViewImpl {
  final CodeMirrorOptions options;

  final ValueChanged<EditorController> onCreate;

  final Function(String val) onValue;

  const CodeMirrorView({
    Key? key,
    required this.options,
    required this.onCreate,
    required this.onValue,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return CodeMirrorViewState();
  }
}

class CodeMirrorViewState extends CodeMirrorViewImplState<CodeMirrorView> {
  /// 编辑器页面（assets/codemirror/index.html）与其依赖的 CodeMirror 资源
  /// 全部随 App 打包，以本地文件方式加载。原实现把 HTML 里的资源指向
  /// unpkg.com 再用 data: URL 装载，国内访问 unpkg 极慢甚至不可达，
  /// 打开脚本/配置编辑器要等它拉完 20 多个文件，表现为长时间空白。
  static const String _editorAssetKey = 'assets/codemirror/index.html';

  WebViewController? _controller;

  bool readOnly = false;
  bool isLoaded = false;

  /// onPageFinished 只会真正处理一次（避免重复注册 onCreate）。
  bool _pageReady = false;

  static bool isLoadedJs = false;
  bool isShowSearch = false;

  Future<void> showSearchBar() async {
    if (isShowSearch) {
      await _controller?.runJavascript(
        'clearSearchText()',
      );
    } else {
      await _controller?.runJavascript(
        'searchText()',
      );
    }
    isShowSearch = !isShowSearch;
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    return LayoutBuilder(
      builder: (context, dimens) {
        return KeyboardVisibilityBuilder(builder: (context, isKeyboardVisible) {
          if (isLoaded) {
            _controller?.runJavascript(
              'editor.setSize(${dimens.maxWidth},${dimens.maxHeight})',
            );
          }

          return WebView(
            backgroundColor: ref.watch(themeProvider).themeColor.codeBgColor(),
            debuggingEnabled: true,
            onWebViewCreated: (controller) {
              if (MultiAccountPageState.useAction().isEmpty) {
                if (!isLoadedJs) {
                  isLoadedJs = true;
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    EasyLoading.show(status: "加载中");
                  });
                }
              }
              _controller = controller;
              // 本地资源加载：不联网，编辑器可即时就绪
              controller.loadFlutterAsset(_editorAssetKey);
            },
            onPageFinished: (url) {
              if (_pageReady) return;
              _pageReady = true;
              _controller?.runJavascript(
                'editor.setSize(${dimens.maxWidth},${dimens.maxHeight})',
              );
              widget.onCreate(EditorController(
                setOptions: (val) async {
                  readOnly = val.readOnly;
                  _controller?.runJavascript(
                    'editor.setSize(${dimens.maxWidth},${dimens.maxHeight})',
                  );

                  // setMode 同时切换语法模式与其对应的 gutters（含原实现里
                  // shell 模式不显示行号/折叠槽的行为）
                  await _controller?.runJavascript(
                    'setMode("${val.mode}")',
                  );
                  await _controller?.runJavascript(
                    'editor.setOption("theme", "${val.theme}")',
                  );
                  await _controller?.runJavascript(
                    'editor.setOption("readOnly", ${val.readOnly ? '\"nocursor\"' : false})',
                  );

                  await _controller?.runJavascript(
                    'editor.setOption("lineNumbers", ${val.showLineNumber})',
                  );
                  await Future.delayed(
                    const Duration(milliseconds: 200),
                  );
                  await _controller?.runJavascript(
                    'editor.refresh()',
                  );
                  await EasyLoading.dismiss();
                  // 所有主题与语言模式的资源都已随 App 打包，切换时只需重新
                  // 应用选项即可，不必像原实现那样整页重载。
                  if (widget.options.mode != val.mode || widget.options.theme != val.theme) {
                    await _controller?.runJavascript('setMode("${val.mode}")');
                    await _controller?.runJavascript(
                      'editor.setOption("theme", "${val.theme}")',
                    );
                    await _controller?.runJavascript('editor.refresh()');
                  }
                },
                setValue: (val) async {
                  TextPainter painter = TextPainter(
                    text: TextSpan(
                      text: val,
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                    textDirection: TextDirection.ltr,
                  );
                  painter.layout(
                    maxWidth: MediaQuery.of(context).size.width,
                  );
                  isLoaded = true;
                  final raw = Uri.encodeComponent(val);
                  _controller?.runJavascript('editor.setValue(decodeURIComponent("$raw"))');
                },
                refresh: () async {
                  const delay = Duration(milliseconds: 50);
                  await Future.delayed(delay);
                  _controller?.runJavascript(
                    'editor.refresh()',
                  );
                },
              ));
            },
            javascriptMode: JavascriptMode.unrestricted,
            javascriptChannels: {
              JavascriptChannel(
                name: 'MessageInvoker',
                onMessageReceived: (event) => widget.onValue(event.message),
              ),
            },
          );
        });
      },
    );
  }
}
