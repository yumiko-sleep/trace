import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/models/stats.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/task_repository.dart';
import '../../goals/providers/goal_providers.dart';

/// ============================================================
/// 「今日任务」板块的状态与操作。
/// ============================================================

/// 当前查看的日期（默认今天）。以后要加日历选日期，只改这里。
final StateProvider<DateTime> selectedDayProvider = StateProvider<DateTime>(
  (Ref ref) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  },
);

/// 某天的任务列表（响应式：数据库一变，界面自动刷新）。
final AutoDisposeStreamProvider<List<Task>> tasksOfDayProvider =
    StreamProvider.autoDispose<List<Task>>((Ref ref) {
  final TaskRepository repo = ref.watch(taskRepositoryProvider);
  return repo.watchByDay(ref.watch(selectedDayProvider));
});

/// goalId → 目标标题，给任务卡片的标签用。
/// （目标列表本身由 goals 板块的 allGoalsProvider 提供，两个板块共用同一份数据）
final Provider<Map<int, String>> goalTitlesProvider =
    Provider<Map<int, String>>((Ref ref) {
  final List<Goal> goals =
      ref.watch(allGoalsProvider).valueOrNull ?? const <Goal>[];
  return <int, String>{for (final Goal g in goals) g.id: g.title};
});

/// 任务列表筛选。
enum TaskFilter { all, pending, done }

extension TaskFilterX on TaskFilter {
  String get label => switch (this) {
        TaskFilter.all => '全部',
        TaskFilter.pending => '待完成',
        TaskFilter.done => '已完成',
      };
}

final StateProvider<TaskFilter> taskFilterProvider =
    StateProvider<TaskFilter>((Ref ref) => TaskFilter.all);

/// 筛选后实际展示的任务。
final Provider<List<Task>> visibleTasksProvider = Provider<List<Task>>(
  (Ref ref) {
    final List<Task> tasks =
        ref.watch(tasksOfDayProvider).valueOrNull ?? const <Task>[];
    return switch (ref.watch(taskFilterProvider)) {
      TaskFilter.all => tasks,
      TaskFilter.pending => tasks.where((Task t) => !t.isDone).toList(),
      TaskFilter.done => tasks.where((Task t) => t.isDone).toList(),
    };
  },
);

/// 今日完成情况。
final Provider<DayTaskStats> taskStatsProvider = Provider<DayTaskStats>(
  (Ref ref) {
    final List<Task> tasks =
        ref.watch(tasksOfDayProvider).valueOrNull ?? const <Task>[];
    return DayTaskStats(
      total: tasks.length,
      done: tasks.where((Task t) => t.isDone).length,
    );
  },
);

/// 今日任务的写操作集合（UI 只调它，不直接碰 Repository/DAO）。
final Provider<TaskActions> taskActionsProvider =
    Provider<TaskActions>((Ref ref) => TaskActions(ref));

class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  TaskRepository get _repo => _ref.read(taskRepositoryProvider);

  Future<int> add({
    required String title,
    String note = '',
    DateTime? dueDate,
    int? goalId,
    int priority = 1,
  }) {
    return _repo.add(
      title: title,
      note: note,
      dueDate: dueDate ?? _ref.read(selectedDayProvider),
      goalId: goalId,
      priority: priority,
    );
  }

  Future<int> update(
    int id, {
    String? title,
    String? note,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? goalId,
    bool clearGoal = false,
    int? priority,
  }) {
    return _repo.edit(
      id,
      title: title,
      note: note,
      dueDate: dueDate,
      clearDueDate: clearDueDate,
      goalId: goalId,
      clearGoal: clearGoal,
      priority: priority,
    );
  }

  /// 勾选 / 取消勾选。
  Future<int> toggle(Task task) => _repo.markDone(task.id, !task.isDone);

  Future<int> remove(Task task) => _repo.remove(task.id);

  /// 撤销删除。
  Future<int> restore(Task task) => _repo.restore(task);

  /// 把今天没做完的任务顺延到明天。
  Future<int> movePendingToTomorrow() {
    final DateTime today = _ref.read(selectedDayProvider);
    return _repo.moveIncompleteTo(today, today.add(const Duration(days: 1)));
  }

  Future<int> clearDone() => _repo.clearDone();
}
