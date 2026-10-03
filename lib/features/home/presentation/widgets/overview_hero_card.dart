import 'package:flutter/material.dart';

import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_count.dart';
import '../../../../core/widgets/gradient_ring.dart';

/// 主页顶部概览卡：渐变底 + 今日完成度环形进度 + 关键数据位。
///
/// 数字全部来自真实数据（今日任务完成情况 + 目标统计）。
class OverviewHeroCard extends StatelessWidget {
  const OverviewHeroCard({
    super.key,
    required this.taskDone,
    required this.taskTotal,
    required this.goalActive,
    required this.goalDone,
  });

  /// 今天做完的任务数
  final int taskDone;

  /// 今天安排的任务总数
  final int taskTotal;

  /// 进行中的目标数
  final int goalActive;

  /// 已完成的目标数
  final int goalDone;

  double get _progress => taskTotal == 0 ? 0 : taskDone / taskTotal;

  String get _footer {
    if (taskTotal == 0) return '今天还没有安排任务，去「今日任务」加一条吧。';
    if (taskDone == taskTotal) return '今天的任务全部完成，厉害 🎉';
    return '还剩 ${taskTotal - taskDone} 件没完成，一件一件来。';
  }

  static const TextStyle _valueStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: c.header,
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.cyan.withValues(alpha: c.isDark ? 0.34 : 0.32),
            blurRadius: 30,
            offset: const Offset(0, 16),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -40,
            top: -50,
            child: IgnorePointer(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -70,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '今日概览',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  GradientRing(
                    progress: _progress,
                    size: 96,
                    stroke: 9,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AnimatedCount(
                          value: _progress * 100,
                          suffix: '%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '完成度',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _StatLine(
                          label: '今日任务',
                          value: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              AnimatedCount(
                                value: taskDone.toDouble(),
                                style: _valueStyle,
                              ),
                              Text('/$taskTotal', style: _valueStyle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 11),
                        _StatLine(
                          label: '进行中目标',
                          value: AnimatedCount(
                            value: goalActive.toDouble(),
                            style: _valueStyle,
                          ),
                        ),
                        const SizedBox(height: 11),
                        _StatLine(
                          label: '已完成目标',
                          value: AnimatedCount(
                            value: goalDone.toDouble(),
                            style: _valueStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: Colors.white.withValues(alpha: 0.28), height: 1),
              const SizedBox(height: 12),
              Text(
                _footer,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12.5,
            ),
          ),
        ),
        value,
      ],
    );
  }
}
