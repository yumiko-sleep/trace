import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 数字滚动：首次挂载从 0 滚到目标值，之后数值变化也会平滑过渡。
///
/// 用在所有「统计数字」上——完成度百分比、任务计数、目标数等，
/// 让数据的变化被看见，而不是瞬间跳变。
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.textAlign,
    this.duration = AppMotion.slow,
    this.curve = AppMotion.emphasized,
  });

  final double value;

  /// 小数位（0 表示取整）
  final int decimals;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;
  final Curve curve;

  String _format(double v) {
    final String number =
        decimals == 0 ? v.round().toString() : v.toStringAsFixed(decimals);
    return '$prefix$number$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (BuildContext context, double v, Widget? _) => Text(
        _format(v),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
