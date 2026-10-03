import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/section_scaffold.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../providers/goal_providers.dart';
import 'widgets/empty_goals_view.dart';
import 'widgets/goal_card.dart';
import 'widgets/goal_category_selector.dart';
import 'widgets/goal_editor_sheet.dart';
import 'widgets/goal_summary_card.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// 板块 2：目标（今日 / 今年 / 人生）。
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScheme c = context.scheme;
    final GoalCategory category = ref.watch(goalCategoryProvider);
    final AsyncValue<List<Goal>> asyncGoals =
        ref.watch(goalsOfCategoryProvider);
    final GoalCategoryStats stats = ref.watch(goalCategoryStatsProvider);
    final List<Goal> goals = asyncGoals.valueOrNull ?? const <Goal>[];

    final Map<int, DayTaskStats> taskStats =
        ref.watch(goalTaskStatsProvider).valueOrNull ??
            const <int, DayTaskStats>{};
    final Map<int, String> goalTitles = <int, String>{
      for (final Goal g in ref.watch(allGoalsProvider).valueOrNull ??
          const <Goal>[])
        g.id: g.title,
    };

    return SectionScaffold(
      title: '目标',
      subtitle: '把想成为的自己，拆成今天就能推进的一步',
      icon: Icons.flag_rounded,
      gradient: c.goals,
      bottomPadding: 120,
      floatingActionButton: AddGoalButton(
        onTap: () => showGoalEditor(context),
      ),
      children: <Widget>[
        GoalCategorySelector(
          value: category,
          onChanged: (GoalCategory c) =>
              ref.read(goalCategoryProvider.notifier).state = c,
        ),
        const SizedBox(height: 18),
        GoalSummaryCard(category: category, stats: stats),
        const SizedBox(height: 20),
        SectionHeader(
          title: '${category.label}列表',
          subtitle: goals.isEmpty
              ? '点右下角「新增目标」开始'
              : '点卡片可以编辑，左滑删除',
        ),
        const SizedBox(height: 14),
        if (asyncGoals.isLoading && !asyncGoals.hasValue)
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
        else if (goals.isEmpty)
          EmptyGoalsView(
            category: category,
            onAdd: () => showGoalEditor(context),
          )
        else
          for (final Goal goal in goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GoalCard(
                goal: goal,
                taskStats: taskStats[goal.id],
                parentTitle:
                    goal.parentId == null ? null : goalTitles[goal.parentId],
                onTap: () => showGoalEditor(context, goal: goal),
                onDelete: () => _deleteGoal(context, ref, goal),
              ),
            ),
      ],
    );
  }

  /// 删除 + 撤销提示条。
  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(goalActionsProvider).remove(goal);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除「${goal.title}」'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => ref.read(goalActionsProvider).restore(goal),
          ),
        ),
      );
  }
}
