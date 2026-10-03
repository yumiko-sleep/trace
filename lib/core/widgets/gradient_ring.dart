import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 渐变环形进度。用 CustomPainter 绘制，支持任意渐变色与圆角端点。
///
/// 数值变化会自己补一段过渡动画（挂载时从 0 画到目标值），
/// 所以打在任务 / 目标页里进度是「长出来」的，而不是瞬间跳变。
class GradientRing extends StatelessWidget {
  const GradientRing({
    super.key,
    required this.progress,
    this.size = 96,
    this.stroke = 10,
    this.colors = const <Color>[Colors.white, Color(0xCCFFFFFF)],
    this.trackColor = const Color(0x40FFFFFF),
    this.center,
    this.duration = AppMotion.slow,
    this.animate = true,
  });

  final double progress;
  final double size;
  final double stroke;
  final List<Color> colors;
  final Color trackColor;
  final Widget? center;
  final Duration duration;

  /// 关掉动画（例如截图、某些测试场景）。
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final double target = progress.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: animate
          ? TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: target),
              duration: duration,
              curve: AppMotion.emphasized,
              builder: (BuildContext context, double value, Widget? _) =>
                  _ring(value),
            )
          : _ring(target),
    );
  }

  Widget _ring(double value) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            progress: value,
            stroke: stroke,
            colors: colors,
            trackColor: trackColor,
          ),
        ),
        if (center != null) center!,
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.colors,
    required this.trackColor,
  });

  final double progress;
  final double stroke;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    final double p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0) return;

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * p, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.trackColor != trackColor ||
      old.colors != colors;
}
