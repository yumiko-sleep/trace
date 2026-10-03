import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../db/app_database.dart';
import '../models/enums.dart';

/// 日志 DAO：学习/训练计划（journal_plans）+ 每日记录与复盘（journal_logs）。
class JournalDao {
  JournalDao(this._db);

  final AppDatabase _db;

  $JournalPlansTable get _plans => _db.journalPlans;
  $JournalLogsTable get _logs => _db.journalLogs;

  static List<OrderClauseGenerator<$JournalPlansTable>> get _planOrder =>
      <OrderClauseGenerator<$JournalPlansTable>>[
        ($JournalPlansTable t) => OrderingTerm(expression: t.sortOrder),
        ($JournalPlansTable t) => OrderingTerm(expression: t.id),
      ];

  static List<OrderClauseGenerator<$JournalLogsTable>> get _logOrder =>
      <OrderClauseGenerator<$JournalLogsTable>>[
        ($JournalLogsTable t) =>
            OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ];

  // ---------------- 计划 ----------------

  Future<List<JournalPlan>> getPlans(
    JournalType type, {
    bool onlyActive = false,
  }) {
    final query = _db.select(_plans)
      ..where(($JournalPlansTable t) => t.type.equalsValue(type))
      ..orderBy(_planOrder);
    if (onlyActive) {
      query.where(($JournalPlansTable t) => t.isActive.equals(true));
    }
    return query.get();
  }

  Stream<List<JournalPlan>> watchPlans(
    JournalType type, {
    bool onlyActive = false,
  }) {
    final query = _db.select(_plans)
      ..where(($JournalPlansTable t) => t.type.equalsValue(type))
      ..orderBy(_planOrder);
    if (onlyActive) {
      query.where(($JournalPlansTable t) => t.isActive.equals(true));
    }
    return query.watch();
  }

  Future<JournalPlan?> getPlanById(int id) =>
      (_db.select(_plans)..where(($JournalPlansTable t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertPlan(JournalPlansCompanion plan) =>
      _db.into(_plans).insert(plan);

  Future<bool> replacePlan(JournalPlansCompanion plan) =>
      _db.update(_plans).replace(plan);

  Future<int> updatePlan(int id, JournalPlansCompanion fields) =>
      (_db.update(_plans)..where(($JournalPlansTable t) => t.id.equals(id)))
          .write(fields.copyWith(updatedAt: Value<DateTime>(DateTime.now())));

  Future<int> deletePlan(int id) =>
      (_db.delete(_plans)..where(($JournalPlansTable t) => t.id.equals(id)))
          .go();

  /// 恢复一个被删除的计划（撤销用），保留原 id 与时间。
  Future<int> restorePlan(JournalPlan plan) => _db.into(_plans).insert(
        JournalPlansCompanion(
          id: Value<int>(plan.id),
          type: Value<JournalType>(plan.type),
          title: Value<String>(plan.title),
          content: Value<String>(plan.content),
          isActive: Value<bool>(plan.isActive),
          sortOrder: Value<int>(plan.sortOrder),
          createdAt: Value<DateTime>(plan.createdAt),
          updatedAt: Value<DateTime>(plan.updatedAt),
        ),
      );

  // ---------------- 每日记录 / 复盘 ----------------

  Future<List<JournalLog>> getLogs(JournalType type, {DateTime? day}) {
    final query = _db.select(_logs)
      ..where(($JournalLogsTable t) => t.type.equalsValue(type))
      ..orderBy(_logOrder);
    if (day != null) {
      query.where(($JournalLogsTable t) => t.date.equals(DayUtils.dayStart(day)));
    }
    return query.get();
  }

  Stream<List<JournalLog>> watchLogs(JournalType type, {DateTime? day}) {
    final query = _db.select(_logs)
      ..where(($JournalLogsTable t) => t.type.equalsValue(type))
      ..orderBy(_logOrder);
    if (day != null) {
      query.where(($JournalLogsTable t) => t.date.equals(DayUtils.dayStart(day)));
    }
    return query.watch();
  }

  /// 某一天的全部日志（学习 + 训练），供"每日复盘"页使用。
  Future<List<JournalLog>> getLogsOfDay(DateTime day) => (_db.select(_logs)
        ..where(
          ($JournalLogsTable t) => t.date.equals(DayUtils.dayStart(day)),
        ))
      .get();

  Future<JournalLog?> getLogById(int id) =>
      (_db.select(_logs)..where(($JournalLogsTable t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertLog(JournalLogsCompanion log) => _db.into(_logs).insert(log);

  Future<bool> replaceLog(JournalLogsCompanion log) =>
      _db.update(_logs).replace(log);

  Future<int> updateLog(int id, JournalLogsCompanion fields) =>
      (_db.update(_logs)..where(($JournalLogsTable t) => t.id.equals(id)))
          .write(fields.copyWith(updatedAt: Value<DateTime>(DateTime.now())));

  Future<int> deleteLog(int id) =>
      (_db.delete(_logs)..where(($JournalLogsTable t) => t.id.equals(id))).go();

  /// 恢复一条被删除的记录（撤销用），保留原 id 与时间。
  Future<int> restoreLog(JournalLog log) => _db.into(_logs).insert(
        JournalLogsCompanion(
          id: Value<int>(log.id),
          type: Value<JournalType>(log.type),
          date: Value<DateTime>(log.date),
          planId: Value<int?>(log.planId),
          content: Value<String>(log.content),
          durationMinutes: Value<int?>(log.durationMinutes),
          review: Value<String>(log.review),
          createdAt: Value<DateTime>(log.createdAt),
          updatedAt: Value<DateTime>(log.updatedAt),
        ),
      );

  Future<int> deleteLogsOfPlan(int planId) =>
      (_db.delete(_logs)
            ..where(($JournalLogsTable t) => t.planId.equals(planId)))
          .go();
}
