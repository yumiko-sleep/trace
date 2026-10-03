import 'package:flutter/material.dart';

import '../theme/app_scheme.dart';
import '../theme/app_theme.dart';
import 'bounce_tap.dart';

/// 渐变主按钮。onPressed 为 null 时自动进入禁用态。
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.gradient,
    this.height = 54,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final LinearGradient? gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final bool enabled = onPressed != null;
    final LinearGradient g = gradient ?? c.primary;

    return BounceTap(
      onTap: onPressed,
      haptic: enabled,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        height: height,
        decoration: BoxDecoration(
          gradient: enabled ? g : c.disabled,
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: g.colors.last.withValues(alpha: 0.34),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                    spreadRadius: -8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
