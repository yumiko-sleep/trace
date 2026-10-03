import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 错峰进场：淡入 + 轻微上移。用 index 控制延迟，实现逐条出现的节奏感。
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 0.10,
    this.duration = AppMotion.slow,
  });

  final Widget child;
  final int index;

  /// 初始下移比例（相对自身高度）。
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offset),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.emphasized));

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppMotion.stagger * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
