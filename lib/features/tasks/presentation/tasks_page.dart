import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/day_utils.dart';
import '../../../core/widgets/bounce_tap.dart';
import '../../../core/widgets/section_scaffold.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/stats.dart';
import '../providers/task_providers.dart';
import 'widgets/empty_tasks_view.dart';
import 'widgets/task_editor_sheet.dart';
import 'widgets/task_filter_bar.dart';
import 'widgets/task_progress_card.dart';
import 'widgets/task_tile.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// 板块 1：今日任务。
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScheme c = context.scheme;
    final AsyncValue<List<Task>> asyncTasks = ref.watch(tasksOfDayProvider);
    final DayTaskStats stats = ref.watch(taskStatsProvider);
    final List<Task> visible = ref.watch(visibleTasksProvider);
    final Map<int, String> goalTitles = ref.watch(goalTitlesProvider);
    final DateTime day = ref.watch(selectedDayProvider);
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final bool hasPending = stats.total > stats.done;

    return SectionScaffold(
      title: '今日任务',
      subtitle: '${DayUtils.formatDate(day)} · 完成 ${stats.done}/${stats.total}',
      icon: Icons.task_alt_rounded,
      gradient: c.tasks,
      bottomPadding: 120,
      floatingActionButton: _AddTaskButton(
        onTap: () => showTaskEditor(context),
      ),
      children: <Widget>[
        TaskProgressCard(stats: stats),
        const SizedBox(height: 18),
        TaskFilterBar(
          value: filter,
          onChanged: (TaskFilter f) =>
              ref.read(taskFilterProvider.notifier).state = f,
          onMovePending: hasPending ? () => _movePending(context, ref) : null,
        ),
        const SizedBox(height: 16),
        if (asyncTasks.isLoading && !asyncTasks.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (visible.isEmpty)
          EmptyTasksView(
            filter: filter,
            onAdd: () => showTaskEditor(context),
          )
        else
          for (final Task task in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TaskTile(
                task: task,
                goalTitle:
                    task.goalId == null ? null : goalTitles[task.goalId],
                onToggle: () => ref.read(taskActionsProvider).toggle(task),
                onDelete: () => _deleteTask(context, ref, task),
                onTap: () => showTaskEditor(context, task: task),
              ),
            ),
      ],
    );
  }

  /// 删除 + 撤销提示条。
  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(taskActionsProvider).remove(task);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除「${task.title}」'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => ref.read(taskActionsProvider).restore(task),
          ),
        ),
      );
  }

  /// 把今天未完成的任务顺延到明天。
  Future<void> _movePending(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int count = await ref.read(taskActionsProvider).movePendingToTomorrow();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 0 ? '没有需要顺延的任务' : '已把 $count 件未完成任务顺延到明天',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

/// 右下角「新增任务」悬浮按钮。
class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({required this.onTap});

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
          gradient: c.tasks,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.cyan.withValues(alpha: 0.38),
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
              '新增任务',
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
