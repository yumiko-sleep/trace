import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/swipe_to_delete.dart';
import '../../../../data/db/app_database.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 优先级对应的颜色（左侧竖条）。
Color priorityColor(int priority, AppScheme c) => switch (priority) {
      2 => c.danger,
      1 => c.cyan,
      _ => c.inkFaint,
    };

String priorityLabel(int priority) => switch (priority) {
      2 => '高',
      1 => '中',
      _ => '低',
    };

/// 单个任务卡片。
///
/// 左滑出现删除区，滑过一半就删除；点一下进入编辑。
///
/// 性能要点：
/// 1. 左侧优先级色条用 [Border] 画（而不是「Stack + ClipRRect + 竖条」），
///    省掉一次 `ClipRRect` 的离屏合成；
/// 2. 整张卡片包在 [RepaintBoundary] 里，勾选动画和左滑动画都只动它自己这一层。
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.goalTitle,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  /// 关联目标的标题（没有关联时为 null）。
  final String? goalTitle;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color accent =
        task.isDone ? c.line : priorityColor(task.priority, c);

    return SwipeToDelete(
      onDelete: onDelete,
      onTap: onTap,
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border(
              left: BorderSide(color: accent, width: 4),
              top: BorderSide(color: c.line),
              right: BorderSide(color: c.line),
              bottom: BorderSide(color: c.line),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.ink.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: TaskCheckbox(done: task.isDone, onTap: onToggle),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildTitle(context),
                    if (task.note.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        task.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: task.isDone
                              ? c.inkFaint.withValues(alpha: 0.7)
                              : c.inkSoft,
                        ),
                      ),
                    ],
                    if (goalTitle != null) ...<Widget>[
                      const SizedBox(height: 8),
                      _GoalTag(title: goalTitle!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final AppScheme c = context.scheme;
    return AnimatedDefaultTextStyle(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      style: TextStyle(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: task.isDone ? c.inkFaint : c.ink,
        decoration:
            task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: c.inkFaint,
        decorationThickness: 1.5,
      ),
      child: Text(task.title),
    );
  }
}

/// 圆形勾选框：勾选时渐变填充 + 打勾图标回弹放大。
class TaskCheckbox extends StatelessWidget {
  const TaskCheckbox({super.key, required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return BounceTap(
      onTap: onTap,
      scale: 0.86,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: done ? c.primary : null,
          border: done
              ? null
              : Border.all(
                  color: c.inkFaint.withValues(alpha: 0.55),
                  width: 2,
                ),
          boxShadow: done
              ? <BoxShadow>[
                  BoxShadow(
                    color: c.cyan.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: AnimatedScale(
          scale: done ? 1 : 0,
          duration: AppMotion.medium,
          curve: AppMotion.spring,
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GoalTag extends StatelessWidget {
  const _GoalTag({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.sky.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.flag_rounded, size: 11, color: c.sky),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.sky,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
