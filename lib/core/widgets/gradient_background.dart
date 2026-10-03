import 'package:flutter/material.dart';

import '../theme/app_scheme.dart';
import '../theme/app_theme.dart';

/// 全屏渐变背景 + 两枚柔光光斑，用于制造干净的层次感。
///
/// 配色跟随当前方案（`context.scheme`）：浅色是极浅的冷/暖白，深色是低亮度底色。
///
/// 性能要点：背景只在换肤时变化，所以单独放进 [RepaintBoundary] 成为独立图层。
/// 这样上层内容（任务列表、滚动、动画）重绘时，渐变和光斑不需要跟着重画一遍。
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: c.page),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: -110,
                    right: -80,
                    child: IgnorePointer(
                      child: _Blob(color: c.mint, size: 280, dark: c.isDark),
                    ),
                  ),
                  Positioned(
                    top: 220,
                    left: -130,
                    child: IgnorePointer(
                      child: _Blob(color: c.sky, size: 320, dark: c.isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.dark});

  final Color color;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final double alpha = dark ? 0.13 : 0.20;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
