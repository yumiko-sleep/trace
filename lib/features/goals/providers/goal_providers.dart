import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/goal_repository.dart';

/// ============================================================
/// 「目标」板块的状态与操作。
/// ============================================================

/// 当前查看的分类（今日 / 今年 / 人生）。
final StateProvider<GoalCategory> goalCategoryProvider =
    StateProvider<GoalCategory>((Ref ref) => GoalCategory.today);

/// 当前分类下的目标（响应式）。
final AutoDisposeStreamProvider<List<Goal>> goalsOfCategoryProvider =
    StreamProvider.autoDispose<List<Goal>>((Ref ref) {
  final GoalRepository repo = ref.watch(goalRepositoryProvider);
  return repo.watchByCategory(ref.watch(goalCategoryProvider));
});

/// 全部目标（编辑弹窗里选「上一级目标」用）。
final AutoDisposeStreamProvider<List<Goal>> allGoalsProvider =
    StreamProvider.autoDispose<List<Goal>>((Ref ref) {
  return ref.watch(goalRepositoryProvider).watchAll();
});

/// goalId → 该目标关联任务的完成情况。
final AutoDisposeStreamProvider<Map<int, DayTaskStats>> goalTaskStatsProvider =
    StreamProvider.autoDispose<Map<int, DayTaskStats>>((Ref ref) {
  return ref.watch(taskRepositoryProvider).watchLinkedStats();
});

/// 当前分类的汇总（总数 / 已完成 / 平均进度）。
final Provider<GoalCategoryStats> goalCategoryStatsProvider =
    Provider<GoalCategoryStats>((Ref ref) {
  final List<Goal> goals =
      ref.watch(goalsOfCategoryProvider).valueOrNull ?? const <Goal>[];
  if (goals.isEmpty) {
    return const GoalCategoryStats(total: 0, done: 0, averageProgress: 0);
  }
  final double sum = goals.fold<double>(
    0,
    (double acc, Goal g) => acc + g.progress,
  );
  return GoalCategoryStats(
    total: goals.length,
    done: goals.where((Goal g) => g.status == GoalStatus.done).length,
    averageProgress: sum / goals.length,
  );
});

/// 分类的层级关系：今日目标挂在今年目标下，今年目标挂在人生目标下。
GoalCategory? parentCategoryOf(GoalCategory category) => switch (category) {
      GoalCategory.today => GoalCategory.thisYear,
      GoalCategory.thisYear => GoalCategory.life,
      GoalCategory.life => null,
    };

/// 目标相关写操作。
final Provider<GoalActions> goalActionsProvider =
    Provider<GoalActions>((Ref ref) => GoalActions(ref));

class GoalActions {
  GoalActions(this._ref);

  final Ref _ref;

  GoalRepository get _repo => _ref.read(goalRepositoryProvider);

  Future<int> add({
    required String title,
    required GoalCategory category,
    String description = '',
    double progress = 0,
    DateTime? deadline,
    GoalStatus status = GoalStatus.active,
    int? parentId,
  }) {
    return _repo.add(
      title: title,
      category: category,
      description: description,
      progress: progress,
      deadline: deadline,
      status: status,
      parentId: parentId,
    );
  }

  Future<int> update(
    int id, {
    String? title,
    String? description,
    GoalCategory? category,
    double? progress,
    DateTime? deadline,
    bool clearDeadline = false,
    GoalStatus? status,
    int? parentId,
    bool clearParent = false,
  }) {
    return _repo.edit(
      id,
      title: title,
      description: description,
      category: category,
      progress: progress,
      deadline: deadline,
      clearDeadline: clearDeadline,
      status: status,
      parentId: parentId,
      clearParent: clearParent,
    );
  }

  Future<int> setProgress(int id, double progress) =>
      _repo.updateProgress(id, progress);

  Future<int> markDone(int id) => _repo.markDone(id);

  Future<int> remove(Goal goal) => _repo.remove(goal.id);

  /// 撤销删除。
  Future<int> restore(Goal goal) => _repo.restore(goal);
}
