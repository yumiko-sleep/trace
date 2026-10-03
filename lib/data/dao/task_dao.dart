import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../db/app_database.dart';

/// 任务表 DAO：只负责 SQL，不做业务判断。
class TaskDao {
  TaskDao(this._db);

  final AppDatabase _db;

  $TasksTable get _table => _db.tasks;

  static List<OrderClauseGenerator<$TasksTable>> get _order =>
      <OrderClauseGenerator<$TasksTable>>[
        ($TasksTable t) => OrderingTerm(expression: t.isDone),
        ($TasksTable t) => OrderingTerm(expression: t.sortOrder),
        ($TasksTable t) =>
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ];

  // ---------------- 查询 ----------------

  Future<List<Task>> getAll() =>
      (_db.select(_table)..orderBy(_order)).get();

  Stream<List<Task>> watchAll() =>
      (_db.select(_table)..orderBy(_order)).watch();

  Future<List<Task>> getByDay(DateTime day) => (_db.select(_table)
        ..where(
          ($TasksTable t) => t.dueDate.isBetweenValues(
            DayUtils.dayStart(day),
            DayUtils.dayEnd(day),
          ),
        )
        ..orderBy(_order))
      .get();

  Stream<List<Task>> watchByDay(DateTime day) => (_db.select(_table)
        ..where(
          ($TasksTable t) => t.dueDate.isBetweenValues(
            DayUtils.dayStart(day),
            DayUtils.dayEnd(day),
          ),
        )
        ..orderBy(_order))
      .watch();

  Future<List<Task>> getByGoal(int goalId) => (_db.select(_table)
        ..where(($TasksTable t) => t.goalId.equals(goalId))
        ..orderBy(_order))
      .get();

  /// 所有「关联了目标」的任务（用于按目标汇总完成情况，一条 SQL 拿完）。
  Future<List<Task>> getLinked() => (_db.select(_table)
        ..where(($TasksTable t) => t.goalId.isNotNull()))
      .get();

  Stream<List<Task>> watchLinked() => (_db.select(_table)
        ..where(($TasksTable t) => t.goalId.isNotNull()))
      .watch();

  Future<Task?> getById(int id) =>
      (_db.select(_table)..where(($TasksTable t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> countAll() async => (await getAll()).length;

  Future<int> countDone() async {
    final List<Task> rows = await (_db.select(_table)
          ..where(($TasksTable t) => t.isDone.equals(true)))
        .get();
    return rows.length;
  }

  // ---------------- 写入 ----------------

  Future<int> insert(TasksCompanion task) => _db.into(_table).insert(task);

  Future<void> insertMany(List<TasksCompanion> tasks) =>
      _db.batch((Batch b) => b.insertAll(_table, tasks));

  /// 整行替换（companion 里要带 id）。
  Future<bool> replace(TasksCompanion task) => _db.update(_table).replace(task);

  /// 局部更新，并自动刷新 updatedAt。
  Future<int> updateFields(int id, TasksCompanion fields) =>
      (_db.update(_table)..where(($TasksTable t) => t.id.equals(id))).write(
        fields.copyWith(updatedAt: Value<DateTime>(DateTime.now())),
      );

  /// 勾选 / 取消勾选。
  Future<int> setDone(int id, bool done) => updateFields(
        id,
        TasksCompanion(
          isDone: Value<bool>(done),
          doneAt: Value<DateTime?>(done ? DateTime.now() : null),
        ),
      );

  Future<int> deleteById(int id) =>
      (_db.delete(_table)..where(($TasksTable t) => t.id.equals(id))).go();

  /// 清掉所有已完成的任务。
  Future<int> deleteDone() =>
      (_db.delete(_table)..where(($TasksTable t) => t.isDone.equals(true))).go();

  Future<int> deleteByGoal(int goalId) => (_db.delete(_table)
        ..where(($TasksTable t) => t.goalId.equals(goalId)))
      .go();

  Future<int> deleteAll() => _db.delete(_table).go();
}
