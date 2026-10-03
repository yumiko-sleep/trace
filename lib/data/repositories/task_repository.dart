import 'package:drift/drift.dart';

import '../dao/task_dao.dart';
import '../db/app_database.dart';
import '../models/stats.dart';

/// 任务仓储：UI 层只通过它读写任务，不直接接触 DAO / 数据库。
class TaskRepository {
  TaskRepository(this._dao);

  final TaskDao _dao;

  // ---------------- 读 ----------------

  Future<List<Task>> getAll() => _dao.getAll();

  Stream<List<Task>> watchAll() => _dao.watchAll();

  Future<List<Task>> getByDay(DateTime day) => _dao.getByDay(day);

  Stream<List<Task>> watchByDay(DateTime day) => _dao.watchByDay(day);

  Future<List<Task>> getByGoal(int goalId) => _dao.getByGoal(goalId);

  /// 按目标分组的任务完成情况（响应式，一条 SQL 拿完再分组）。
  Stream<Map<int, DayTaskStats>> watchLinkedStats() =>
      _dao.watchLinked().map(_groupByGoal);

  Future<Map<int, DayTaskStats>> linkedStatsByGoal() async =>
      _groupByGoal(await _dao.getLinked());

  static Map<int, DayTaskStats> _groupByGoal(List<Task> tasks) {
    final Map<int, int> total = <int, int>{};
    final Map<int, int> done = <int, int>{};
    for (final Task task in tasks) {
      final int? goalId = task.goalId;
      if (goalId == null) continue;
      total[goalId] = (total[goalId] ?? 0) + 1;
      if (task.isDone) done[goalId] = (done[goalId] ?? 0) + 1;
    }
    return <int, DayTaskStats>{
      for (final int goalId in total.keys)
        goalId: DayTaskStats(total: total[goalId]!, done: done[goalId] ?? 0),
    };
  }

  Future<Task?> getById(int id) => _dao.getById(id);

  /// 某天的完成情况统计。
  Future<DayTaskStats> statsOfDay(DateTime day) async {
    final List<Task> tasks = await _dao.getByDay(day);
    return DayTaskStats(
      total: tasks.length,
      done: tasks.where((Task t) => t.isDone).length,
    );
  }

  // ---------------- 写 ----------------

  /// 新建任务。
  Future<int> add({
    required String title,
    String note = '',
    DateTime? dueDate,
    int? goalId,
    int priority = 1,
    int sortOrder = 0,
  }) {
    return _dao.insert(
      TasksCompanion.insert(
        title: title.trim(),
        note: Value<String>(note),
        dueDate: Value<DateTime?>(dueDate),
        goalId: Value<int?>(goalId),
        priority: Value<int>(priority),
        sortOrder: Value<int>(sortOrder),
      ),
    );
  }

  /// 编辑任务。传 null 表示该字段不改；要清空可空字段请用 clearXxx。
  Future<int> edit(
    int id, {
    String? title,
    String? note,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? goalId,
    bool clearGoal = false,
    int? priority,
    int? sortOrder,
  }) {
    return _dao.updateFields(
      id,
      TasksCompanion(
        title: title == null ? const Value.absent() : Value<String>(title.trim()),
        note: note == null ? const Value.absent() : Value<String>(note),
        dueDate: clearDueDate
            ? const Value<DateTime?>(null)
            : (dueDate == null ? const Value.absent() : Value<DateTime?>(dueDate)),
        goalId: clearGoal
            ? const Value<int?>(null)
            : (goalId == null ? const Value.absent() : Value<int?>(goalId)),
        priority: priority == null ? const Value.absent() : Value<int>(priority),
        sortOrder:
            sortOrder == null ? const Value.absent() : Value<int>(sortOrder),
      ),
    );
  }

  Future<int> markDone(int id, bool done) => _dao.setDone(id, done);

  /// 勾选 / 取消勾选。
  Future<int> toggleDone(int id) async {
    final Task? task = await _dao.getById(id);
    if (task == null) return 0;
    return _dao.setDone(id, !task.isDone);
  }

  Future<int> remove(int id) => _dao.deleteById(id);

  /// 清空所有已完成任务。
  Future<int> clearDone() => _dao.deleteDone();

  /// 恢复一条被删除的任务（「撤销删除」用）。
  ///
  /// 会保留原来的 id、创建时间与勾选状态，所以撤销后和删除前一模一样。
  Future<int> restore(Task task) => _dao.insert(
        TasksCompanion(
          id: Value<int>(task.id),
          title: Value<String>(task.title),
          note: Value<String>(task.note),
          dueDate: Value<DateTime?>(task.dueDate),
          isDone: Value<bool>(task.isDone),
          doneAt: Value<DateTime?>(task.doneAt),
          goalId: Value<int?>(task.goalId),
          priority: Value<int>(task.priority),
          sortOrder: Value<int>(task.sortOrder),
          createdAt: Value<DateTime>(task.createdAt),
          updatedAt: Value<DateTime>(task.updatedAt),
        ),
      );

  /// 把某天未完成的任务顺延到另一天。
  Future<int> moveIncompleteTo(DateTime from, DateTime to) async {
    final List<Task> tasks = await _dao.getByDay(from);
    final List<Task> pending =
        tasks.where((Task t) => !t.isDone).toList(growable: false);
    if (pending.isEmpty) return 0;
    for (final Task task in pending) {
      await _dao.updateFields(
        task.id,
        TasksCompanion(dueDate: Value<DateTime?>(to)),
      );
    }
    return pending.length;
  }
}
