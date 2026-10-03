import 'package:flutter/material.dart';

import '../../../../core/widgets/animated_count.dart';
import '../../../../core/widgets/gradient_ring.dart';
import '../../../../data/models/stats.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 今日完成度卡片：环形进度 + 文案。
class TaskProgressCard extends StatelessWidget {
  const TaskProgressCard({super.key, required this.stats});

  final DayTaskStats stats;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final int pending = stats.total - stats.done;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.tasks,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.cyan.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          GradientRing(
            progress: stats.progress,
            size: 84,
            stroke: 9,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedCount(
                  value: stats.progress * 100,
                  suffix: '%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '完成度',
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
                const Text(
                  '今日完成',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '已完成 ${stats.done} 件 · 共 ${stats.total} 件',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _hint(pending),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hint(int pending) {
    if (stats.isEmpty) return '还没有安排任务，先加一件小事';
    if (pending == 0) return '今天全部完成，厉害 🎉';
    return '还剩 $pending 件，一件一件来';
  }
}
