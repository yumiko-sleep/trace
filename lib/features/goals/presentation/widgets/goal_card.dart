import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/swipe_to_delete.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/stats.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 状态标签的配色。
Color statusColor(GoalStatus status, AppScheme c) => switch (status) {
      GoalStatus.active => c.mintDeep,
      GoalStatus.done => c.sky,
      GoalStatus.paused => c.inkFaint,
    };

/// 截止日期的描述文案。
String deadlineText(DateTime? deadline) {
  if (deadline == null) return '未设截止日期';
  final int days = DayUtils.dayStart(deadline)
      .difference(DayUtils.dayStart(DateTime.now()))
      .inDays;
  if (days < 0) return '已过期 ${-days} 天';
  if (days == 0) return '今天截止';
  return '还剩 $days 天';
}

Color deadlineColor(DateTime? deadline, AppScheme c) {
  if (deadline == null) return c.inkFaint;
  final int days = DayUtils.dayStart(deadline)
      .difference(DayUtils.dayStart(DateTime.now()))
      .inDays;
  if (days < 0) return c.danger;
  if (days <= 7) return c.amber;
  return c.inkSoft;
}

/// 目标卡片：状态标签 + 描述 + 进度条 + 截止倒计时 + 关联任务情况。
///
/// 左滑删除，点一下进入编辑；结构上刻意不用 ClipRRect，
/// 并用 RepaintBoundary 把每张卡片隔成独立图层（和任务卡片同样的处理）。
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    required this.onDelete,
    this.taskStats,
    this.parentTitle,
  });

  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// 该目标下关联任务的完成情况（没有关联任务时为 null）。
  final DayTaskStats? taskStats;

  /// 上一级目标的标题（有层级时展示）。
  final String? parentTitle;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final DayTaskStats? stats = taskStats;

    return SwipeToDelete(
      onDelete: onDelete,
      onTap: onTap,
      radius: 22,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.ink.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: goal.status == GoalStatus.done
                            ? c.inkFaint
                            : c.ink,
                        decoration: goal.status == GoalStatus.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: c.inkFaint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusTag(status: goal.status),
                ],
              ),
              if (goal.description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 7),
                Text(
                  goal.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: c.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _ProgressBar(progress: goal.progress),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.event_rounded,
                    size: 13,
                    color: deadlineColor(goal.deadline, c),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    deadlineText(goal.deadline),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: deadlineColor(goal.deadline, c),
                    ),
                  ),
                  if (stats != null && !stats.isEmpty) ...<Widget>[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.task_alt_rounded,
                      size: 13,
                      color: c.inkFaint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '任务 ${stats.done}/${stats.total}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ],
              ),
              if (parentTitle != null) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 12,
                        color: c.violet,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          parentTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.violet,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final double p = progress.clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              return Stack(
                children: <Widget>[
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.slow,
                    curve: AppMotion.emphasized,
                    height: 7,
                    width: (box.maxWidth * p).clamp(0.0, box.maxWidth),
                    decoration: BoxDecoration(
                      gradient: c.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${(p * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: c.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color color = statusColor(status, c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// 「目标」页顶部悬浮按钮。
class AddGoalButton extends StatelessWidget {
  const AddGoalButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return BounceTap(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: c.goals,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.sky.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 7),
            Text(
              '新增目标',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
