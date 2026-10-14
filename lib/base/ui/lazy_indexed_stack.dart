import 'package:flutter/widgets.dart';

/// 只构建「访问过」的页面的 IndexedStack。
///
/// 首页有 4 个 tab（任务 / 环境变量 / 配置文件 / 我的）。用 IndexedStack 承载可以
/// 保留各 tab 的状态（滚动位置、已加载数据），但它会在首帧把**全部** child 都构建出来 ——
/// 于是 App 一启动就同时构建 4 个页面、各自发起首屏请求，既拖慢启动又白占内存。
///
/// 本组件让未访问过的 tab 先放占位，首次切到才真正构建，之后一直保留。
///
/// ⚠️ 占位必须包在 [Positioned.fill] 里。IndexedStack 是 Stack 的子类且默认
/// `StackFit.loose`，而 `RenderStack._computeSize` 的规则是：
/// 存在**非定位** child 时，尺寸由这些 child 决定（`Size(width, height)`）；
/// 全部为定位 child 时才取 `constraints.biggest`。
/// 原来 4 个 child 全是 `Positioned.fill`，所以主体能撑满整屏；
/// 若把占位写成裸 `SizedBox.shrink()`（非定位、0×0），整个 body 会塌陷成空白。
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    Key? key,
    required this.index,
    required this.children,
    this.initialIndexes = const <int>{0},
  }) : super(key: key);

  final int index;
  final List<Widget> children;

  /// 启动时就构建（＝各自发起首屏请求）的下标集合，其余按需构建。
  ///
  /// 首页传 `{0, 1, 2}`：任务、环境变量、配置文件三页在开 App 时就加载数据
  /// （用户明确要求「任务与环境变量同步加载」；配置文件页还要承接
  /// 「编辑配置文件」快捷入口 —— 那页只有在被构建时才会读取该动作），
  /// 只有「我的」按需构建。
  final Set<int> initialIndexes;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final Set<int> _visited;

  @override
  void initState() {
    super.initState();
    _visited = <int>{...widget.initialIndexes};
  }

  @override
  Widget build(BuildContext context) {
    // 当前页必然要构建；记录后即可在本次 build 中生效，无需 setState
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: List<Widget>.generate(
        widget.children.length,
        (i) => Positioned.fill(
          child: _visited.contains(i)
              ? widget.children[i]
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
