import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// iconKey → 图标。数据库里存字符串，UI 层统一在这里映射。
IconData metricIcon(String iconKey) => switch (iconKey) {
      'bedtime' => Icons.bedtime_rounded,
      'wake' => Icons.wb_twilight_rounded,
      'screen' => Icons.smartphone_rounded,
      'calories' => Icons.local_fire_department_rounded,
      'reading' => Icons.menu_book_rounded,
      'water' => Icons.water_drop_rounded,
      'weight' => Icons.monitor_weight_rounded,
      'sport' => Icons.directions_run_rounded,
      _ => Icons.insights_rounded,
    };

/// 数据项的小圆角图标徽章。
class MetricIconBadge extends StatelessWidget {
  const MetricIconBadge({
    super.key,
    required this.iconKey,
    required this.color,
    this.size = 40,
  });

  final String iconKey;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(metricIcon(iconKey), size: size * 0.5, color: color),
    );
  }
}

/// 数据项名称下面那行小字：类型 + 单位 + 目标值。
String metricMetaText({
  required String typeLabel,
  required String unit,
  double? target,
  required bool lowerIsBetter,
}) {
  final StringBuffer buffer = StringBuffer(typeLabel);
  if (unit.isNotEmpty) buffer.write(' · $unit');
  if (target != null) {
    buffer.write(' · 目标 ${target % 1 == 0 ? target.round() : target}');
    buffer.write(lowerIsBetter ? ' 以内' : ' 以上');
  }
  return buffer.toString();
}

/// 失败 / 提示用的淡色胶囊标签。
class MetricTag extends StatelessWidget {
  const MetricTag({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 数据板块通用的线性进度条（渐变色，宽度变化带动画）。
class MetricProgressBar extends StatelessWidget {
  const MetricProgressBar({super.key, required this.progress, this.height = 7});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final double p = progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return Stack(
          children: <Widget>[
            Container(
              height: height,
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              height: height,
              width: (box.maxWidth * p).clamp(0.0, box.maxWidth),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[c.indigo, c.violet],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        );
      },
    );
  }
}
