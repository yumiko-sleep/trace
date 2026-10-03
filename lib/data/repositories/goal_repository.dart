import 'package:drift/drift.dart';

import '../dao/goal_dao.dart';
import '../db/app_database.dart';
import '../models/enums.dart';
import '../models/stats.dart';

/// 目标仓储。
class GoalRepository {
  GoalRepository(this._dao);

  final GoalDao _dao;

  // ---------------- 读 ----------------

  Future<List<Goal>> getAll() => _dao.getAll();

  Stream<List<Goal>> watchAll() => _dao.watchAll();

  Future<List<Goal>> getByCategory(GoalCategory category) =>
      _dao.getByCategory(category);

  Stream<List<Goal>> watchByCategory(GoalCategory category) =>
      _dao.watchByCategory(category);

  Future<List<Goal>> getChildren(int parentId) => _dao.getChildren(parentId);

  Future<Goal?> getById(int id) => _dao.getById(id);

  /// 各分类的目标完成情况（用于主页概览）。
  Future<Map<GoalCategory, DayTaskStats>> statsByCategory() async {
    final Map<GoalCategory, DayTaskStats> result =
        <GoalCategory, DayTaskStats>{};
    for (final GoalCategory category in GoalCategory.values) {
      final List<Goal> goals = await _dao.getByCategory(category);
      result[category] = DayTaskStats(
        total: goals.length,
        done: goals.where((Goal g) => g.status == GoalStatus.done).length,
      );
    }
    return result;
  }

  // ---------------- 写 ----------------

  Future<int> add({
    required String title,
    required GoalCategory category,
    String description = '',
    double progress = 0,
    DateTime? deadline,
    GoalStatus status = GoalStatus.active,
    int? parentId,
    int sortOrder = 0,
  }) {
    return _dao.insert(
      GoalsCompanion.insert(
        title: title.trim(),
        category: category,
        description: Value<String>(description),
        progress: Value<double>(progress.clamp(0.0, 1.0).toDouble()),
        deadline: Value<DateTime?>(deadline),
        status: Value<GoalStatus>(status),
        parentId: Value<int?>(parentId),
        sortOrder: Value<int>(sortOrder),
      ),
    );
  }

  Future<int> edit(
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
    int? sortOrder,
  }) {
    return _dao.updateFields(
      id,
      GoalsCompanion(
        title: title == null ? const Value.absent() : Value<String>(title.trim()),
        description:
            description == null ? const Value.absent() : Value<String>(description),
        category:
            category == null ? const Value.absent() : Value<GoalCategory>(category),
        progress: progress == null
            ? const Value.absent()
            : Value<double>(progress.clamp(0.0, 1.0).toDouble()),
        deadline: clearDeadline
            ? const Value<DateTime?>(null)
            : (deadline == null
                ? const Value.absent()
                : Value<DateTime?>(deadline)),
        status:
            status == null ? const Value.absent() : Value<GoalStatus>(status),
        parentId: clearParent
            ? const Value<int?>(null)
            : (parentId == null ? const Value.absent() : Value<int?>(parentId)),
        sortOrder:
            sortOrder == null ? const Value.absent() : Value<int>(sortOrder),
      ),
    );
  }

  Future<int> updateProgress(int id, double progress) =>
      _dao.updateProgress(id, progress);

  Future<int> markDone(int id) =>
      _dao.updateFields(id, const GoalsCompanion(status: Value(GoalStatus.done)));

  Future<int> remove(int id) => _dao.deleteById(id);

  /// 恢复一条被删除的目标（「撤销删除」用），保留原 id 与创建时间。
  Future<int> restore(Goal goal) => _dao.insert(
        GoalsCompanion(
          id: Value<int>(goal.id),
          title: Value<String>(goal.title),
          description: Value<String>(goal.description),
          category: Value<GoalCategory>(goal.category),
          progress: Value<double>(goal.progress),
          deadline: Value<DateTime?>(goal.deadline),
          status: Value<GoalStatus>(goal.status),
          parentId: Value<int?>(goal.parentId),
          sortOrder: Value<int>(goal.sortOrder),
          createdAt: Value<DateTime>(goal.createdAt),
          updatedAt: Value<DateTime>(goal.updatedAt),
        ),
      );
}
