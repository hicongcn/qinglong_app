

import 'package:flutter/material.dart';

import 'lazy_indexed_stack.dart';

/// 带淡出/淡入过渡的 IndexedStack（多账号切换用）。
///
/// 内部复用 [LazyIndexedStack]：**未访问过的账号页不会真正构建**。
/// 这一点很关键 —— `IndexedStack` 的每个 child 都会被布局（`RenderIndexedStack`
/// 只重写了绘制，没重写 `performLayout`），而账号页数量默认放开到 5。
/// 若一次性把 5 个账号页都挂上，等于每帧白白布局 4 棵完整页面树，
/// 启动时也要多建 4 套 provider / Http 实例，而绝大多数用户只登录 1 个账号。
class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const AnimatedIndexedStack({
    Key? key,
    required this.index,
    required this.children,
  }) : super(key: key);

  @override
  _AnimatedIndexedStackState createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _index;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.ease,
      ),
    );

    _index = widget.index;
    _controller.forward();
    super.initState();
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _index) {
      _controller.reverse().then((_) {
        setState(() => _index = widget.index);
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Transform.scale(
            scale: 1.015 - (_controller.value * 0.015),
            child: child,
          ),
        );
      },
      child: LazyIndexedStack(
        index: _index,
        children: widget.children,
      ),
    );
  }
}
