import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../providers/task_providers.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 筛选栏：全部 / 待完成 / 已完成 + 「顺延未完成」快捷操作。
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.onMovePending,
  });

  final TaskFilter value;
  final ValueChanged<TaskFilter> onChanged;

  /// 为 null 时不显示（比如已经全部完成）。
  final VoidCallback? onMovePending;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: <Widget>[
                for (final TaskFilter f in TaskFilter.values)
                  Expanded(child: _segment(context, f)),
              ],
            ),
          ),
        ),
        if (onMovePending != null) ...<Widget>[
          const SizedBox(width: 10),
          Tooltip(
            message: '把未完成的任务顺延到明天',
            child: BounceTap(
              onTap: onMovePending,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.line),
                ),
                child: Icon(
                  Icons.redo_rounded,
                  size: 19,
                  color: c.inkSoft,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _segment(BuildContext context, TaskFilter f) {
    final AppScheme c = context.scheme;
    final bool selected = f == value;
    return BounceTap(
      onTap: () => onChanged(f),
      haptic: false,
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? c.primary : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.medium,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : c.inkFaint,
            ),
            child: Text(f.label),
          ),
        ),
      ),
    );
  }
}
