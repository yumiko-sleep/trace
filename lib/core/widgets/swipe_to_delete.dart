import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_scheme.dart';
import '../theme/app_theme.dart';

/// 通用「左滑删除」容器。
///
/// 为什么不直接用 Dismissible：Dismissible 在「删除后列表项必须立刻从树上移除」
/// 这件事上很敏感，配合异步数据库流容易触发
/// "A dismissed Dismissible widget is still part of the tree" 断言。
/// 这里自己用水平拖拽 + 位移动画实现，行为完全可控。
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.onTap,
    this.maxDrag = 96,
    this.radius = 20,
  });

  final Widget child;

  /// 滑出屏幕后调用（此时才真正删数据）。
  final VoidCallback onDelete;

  final VoidCallback? onTap;

  /// 最大可拉动距离，同时也是触发删除的参照值。
  final double maxDrag;
  final double radius;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete> {
  double _target = 0;
  bool _dragging = false;
  bool _pendingDelete = false;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragging = true;
      _target = (_target + details.delta.dx).clamp(-widget.maxDrag, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final bool passed = _target <= -widget.maxDrag * 0.55;
    setState(() {
      _dragging = false;
      if (passed) {
        _pendingDelete = true;
        // 滑出屏幕（比卡片宽度大即可）
        _target = -600;
      } else {
        _target = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _background(context)),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _target),
          duration: _dragging ? Duration.zero : AppMotion.medium,
          curve: AppMotion.emphasized,
          onEnd: () {
            if (_pendingDelete) {
              _pendingDelete = false;
              widget.onDelete();
            }
          },
          builder: (BuildContext context, double value, Widget? child) =>
              Transform.translate(offset: Offset(value, 0), child: child),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: widget.child,
          ),
        ),
      ],
    );
  }

  Widget _background(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.delete_outline_rounded,
            color: c.danger,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            '删除',
            style: TextStyle(
              color: c.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
