import 'package:flutter/material.dart';

import '../theme/app_scheme.dart';
import '../theme/app_theme.dart';
import 'bounce_tap.dart';

/// 柔性卡片：浅描边 + 极淡投影，保持页面干净。
///
/// 底色、描边、投影都来自当前配色方案（深色模式下自动变成深色卡）。
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = 22,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -10,
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return BounceTap(onTap: onTap, scale: 0.98, child: content);
  }
}
