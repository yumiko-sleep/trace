import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../dao/journal_dao.dart';
import '../db/app_database.dart';
import '../models/enums.dart';

/// 日志仓储：学习 / 训练的计划与每日记录。
class JournalRepository {
  JournalRepository(this._dao);

  final JournalDao _dao;

  // ---------------- 计划 ----------------

  Future<List<JournalPlan>> getPlans(
    JournalType type, {
    bool onlyActive = false,
  }) =>
      _dao.getPlans(type, onlyActive: onlyActive);

  Stream<List<JournalPlan>> watchPlans(
    JournalType type, {
    bool onlyActive = false,
  }) =>
      _dao.watchPlans(type, onlyActive: onlyActive);

  Future<JournalPlan?> getPlanById(int id) => _dao.getPlanById(id);

  Future<int> addPlan({
    required JournalType type,
    required String title,
    String content = '',
    int sortOrder = 0,
  }) =>
      _dao.insertPlan(
        JournalPlansCompanion.insert(
          type: type,
          title: title.trim(),
          content: Value<String>(content),
          sortOrder: Value<int>(sortOrder),
        ),
      );

  Future<int> updatePlan(
    int id, {
    String? title,
    String? content,
    bool? isActive,
    int? sortOrder,
  }) =>
      _dao.updatePlan(
        id,
        JournalPlansCompanion(
          title: title == null ? const Value.absent() : Value<String>(title.trim()),
          content: content == null ? const Value.absent() : Value<String>(content),
          isActive:
              isActive == null ? const Value.absent() : Value<bool>(isActive),
          sortOrder:
              sortOrder == null ? const Value.absent() : Value<int>(sortOrder),
        ),
      );

  Future<int> removePlan(int id) => _dao.deletePlan(id);

  /// 撤销删除计划（保留原 id）。
  Future<int> restorePlan(JournalPlan plan) => _dao.restorePlan(plan);

  // ---------------- 每日记录 ----------------

  Future<List<JournalLog>> getLogs(JournalType type, {DateTime? day}) =>
      _dao.getLogs(type, day: day);

  Stream<List<JournalLog>> watchLogs(JournalType type, {DateTime? day}) =>
      _dao.watchLogs(type, day: day);

  Future<List<JournalLog>> getLogsOfDay(DateTime day) =>
      _dao.getLogsOfDay(day);

  Future<JournalLog?> getLogById(int id) => _dao.getLogById(id);

  /// 某天某种类型的记录（约定：同一天同类型只有一条，用 upsert 语义）。
  Future<int> saveLog({
    required JournalType type,
    required DateTime date,
    int? planId,
    String content = '',
    int? durationMinutes,
    String review = '',
  }) async {
    final DateTime day = DayUtils.dayStart(date);
    final List<JournalLog> existing = await _dao.getLogs(type, day: day);
    if (existing.isEmpty) {
      return _dao.insertLog(
        JournalLogsCompanion.insert(
          type: type,
          date: day,
          planId: Value<int?>(planId),
          content: Value<String>(content),
          durationMinutes: Value<int?>(durationMinutes),
          review: Value<String>(review),
        ),
      );
    }
    final JournalLog log = existing.first;
    await _dao.updateLog(
      log.id,
      JournalLogsCompanion(
        planId: planId == null ? const Value.absent() : Value<int?>(planId),
        content: Value<String>(content),
        durationMinutes: Value<int?>(durationMinutes),
        review: Value<String>(review),
      ),
    );
    return log.id;
  }

  /// 只更新复盘段落。
  Future<int> saveReview(int logId, String review) => _dao.updateLog(
        logId,
        JournalLogsCompanion(review: Value<String>(review)),
      );

  /// 只更新正文部分（内容 / 时长 / 关联计划），**不动复盘段落**。
  ///
  /// saveLog 是全量覆盖语义，改内容时用它容易顺手把复盘清掉，
  /// 所以「编辑已有记录」一律走这里。
  Future<int> updateLogContent(
    int logId, {
    required String content,
    int? durationMinutes,
    int? planId,
  }) =>
      _dao.updateLog(
        logId,
        JournalLogsCompanion(
          content: Value<String>(content),
          durationMinutes: Value<int?>(durationMinutes),
          planId: Value<int?>(planId),
        ),
      );

  Future<int> removeLog(int logId) => _dao.deleteLog(logId);

  /// 撤销删除记录（保留原 id）。
  Future<int> restoreLog(JournalLog log) => _dao.restoreLog(log);

  /// 最近 [days] 天里，学习 + 训练的总时长（分钟）。
  Future<int> totalMinutes(int days) async {
    int sum = 0;
    for (final JournalType type in JournalType.values) {
      final List<JournalLog> logs = await _dao.getLogs(type);
      final DateTime from =
          DayUtils.dayStart(DateTime.now()).subtract(Duration(days: days - 1));
      for (final JournalLog log in logs) {
        if (log.date.isBefore(from)) continue;
        sum += log.durationMinutes ?? 0;
      }
    }
    return sum;
  }
}
