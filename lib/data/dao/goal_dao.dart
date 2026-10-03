import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/enums.dart';

/// 目标表 DAO。
class GoalDao {
  GoalDao(this._db);

  final AppDatabase _db;

  $GoalsTable get _table => _db.goals;

  static List<OrderClauseGenerator<$GoalsTable>> get _order =>
      <OrderClauseGenerator<$GoalsTable>>[
        ($GoalsTable t) => OrderingTerm(expression: t.category),
        ($GoalsTable t) => OrderingTerm(expression: t.sortOrder),
        ($GoalsTable t) =>
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ];

  // ---------------- 查询 ----------------

  Future<List<Goal>> getAll() =>
      (_db.select(_table)..orderBy(_order)).get();

  Stream<List<Goal>> watchAll() =>
      (_db.select(_table)..orderBy(_order)).watch();

  Future<List<Goal>> getByCategory(GoalCategory category) => (_db.select(_table)
        ..where(($GoalsTable t) => t.category.equalsValue(category))
        ..orderBy(_order))
      .get();

  Stream<List<Goal>> watchByCategory(GoalCategory category) =>
      (_db.select(_table)
            ..where(($GoalsTable t) => t.category.equalsValue(category))
            ..orderBy(_order))
          .watch();

  Future<List<Goal>> getByStatus(GoalStatus status) => (_db.select(_table)
        ..where(($GoalsTable t) => t.status.equalsValue(status))
        ..orderBy(_order))
      .get();

  /// 某个目标的子目标。
  Future<List<Goal>> getChildren(int parentId) => (_db.select(_table)
        ..where(($GoalsTable t) => t.parentId.equals(parentId))
        ..orderBy(_order))
      .get();

  Future<Goal?> getById(int id) =>
      (_db.select(_table)..where(($GoalsTable t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> countByStatus(GoalStatus status) async {
    final List<Goal> rows = await (_db.select(_table)
          ..where(($GoalsTable t) => t.status.equalsValue(status)))
        .get();
    return rows.length;
  }

  // ---------------- 写入 ----------------

  Future<int> insert(GoalsCompanion goal) => _db.into(_table).insert(goal);

  Future<void> insertMany(List<GoalsCompanion> goals) =>
      _db.batch((Batch b) => b.insertAll(_table, goals));

  Future<bool> replace(GoalsCompanion goal) => _db.update(_table).replace(goal);

  Future<int> updateFields(int id, GoalsCompanion fields) =>
      (_db.update(_table)..where(($GoalsTable t) => t.id.equals(id))).write(
        fields.copyWith(updatedAt: Value<DateTime>(DateTime.now())),
      );

  /// 更新进度（自动夹在 0~1）。
  Future<int> updateProgress(int id, double progress) => updateFields(
        id,
        GoalsCompanion(
          progress: Value<double>(progress.clamp(0.0, 1.0).toDouble()),
        ),
      );

  Future<int> deleteById(int id) =>
      (_db.delete(_table)..where(($GoalsTable t) => t.id.equals(id))).go();

  Future<int> deleteAll() => _db.delete(_table).go();
}
