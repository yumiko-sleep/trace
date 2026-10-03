import 'package:flutter/material.dart';

import '../../../../core/widgets/animated_count.dart';
import '../../../../core/widgets/gradient_ring.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/stats.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 「目标」页顶部的分类汇总卡：平均进度环 + 数量。
class GoalSummaryCard extends StatelessWidget {
  const GoalSummaryCard({
    super.key,
    required this.category,
    required this.stats,
  });

  final GoalCategory category;
  final GoalCategoryStats stats;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.goals,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.sky.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          GradientRing(
            progress: stats.averageProgress,
            size: 84,
            stroke: 9,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedCount(
                  value: stats.averageProgress * 100,
                  suffix: '%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '平均进度',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  category.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  category.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  stats.isEmpty
                      ? '还没有目标，写下一个想达成的结果'
                      : '共 ${stats.total} 个 · 已完成 ${stats.done} 个',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
