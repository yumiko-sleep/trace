import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../db/app_database.dart';

/// 数据板块 DAO：数据项定义（metric_definitions）+ 每日记录（metric_records）。
class MetricDao {
  MetricDao(this._db);

  final AppDatabase _db;

  $MetricDefinitionsTable get _defs => _db.metricDefinitions;
  $MetricRecordsTable get _records => _db.metricRecords;

  static List<OrderClauseGenerator<$MetricDefinitionsTable>> get _defOrder =>
      <OrderClauseGenerator<$MetricDefinitionsTable>>[
        ($MetricDefinitionsTable t) => OrderingTerm(expression: t.sortOrder),
        ($MetricDefinitionsTable t) => OrderingTerm(expression: t.id),
      ];

  static List<OrderClauseGenerator<$MetricRecordsTable>> get _recordOrder =>
      <OrderClauseGenerator<$MetricRecordsTable>>[
        ($MetricRecordsTable t) => OrderingTerm(expression: t.date),
      ];

  // ---------------- 数据项定义 ----------------

  Future<List<MetricDefinition>> getDefinitions({
    bool includeArchived = false,
  }) {
    final query = _db.select(_defs)..orderBy(_defOrder);
    if (!includeArchived) {
      query.where(($MetricDefinitionsTable t) => t.isArchived.equals(false));
    }
    return query.get();
  }

  Stream<List<MetricDefinition>> watchDefinitions({
    bool includeArchived = false,
  }) {
    final query = _db.select(_defs)..orderBy(_defOrder);
    if (!includeArchived) {
      query.where(($MetricDefinitionsTable t) => t.isArchived.equals(false));
    }
    return query.watch();
  }

  Future<MetricDefinition?> getDefinitionById(int id) =>
      (_db.select(_defs)..where(($MetricDefinitionsTable t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<MetricDefinition?> getDefinitionByKey(String key) =>
      (_db.select(_defs)
            ..where(($MetricDefinitionsTable t) => t.key.equals(key)))
          .getSingleOrNull();

  Future<int> insertDefinition(MetricDefinitionsCompanion def) =>
      _db.into(_defs).insert(def);

  Future<bool> replaceDefinition(MetricDefinitionsCompanion def) =>
      _db.update(_defs).replace(def);

  Future<int> updateDefinition(int id, MetricDefinitionsCompanion fields) =>
      (_db.update(_defs)..where(($MetricDefinitionsTable t) => t.id.equals(id)))
          .write(fields);

  /// 归档而不是物理删除：历史记录不会丢。
  Future<int> archiveDefinition(int id, {bool archived = true}) =>
      updateDefinition(
        id,
        MetricDefinitionsCompanion(isArchived: Value<bool>(archived)),
      );

  Future<int> deleteDefinition(int id) =>
      (_db.delete(_defs)..where(($MetricDefinitionsTable t) => t.id.equals(id)))
          .go();

  /// 补种内置数据项（幂等）。用户误删或后续版本新增内置项时可调用。
  Future<void> ensureBuiltInMetrics() => _db.ensureBuiltInMetrics();

  // ---------------- 每日记录 ----------------

  Future<MetricRecord?> getRecord(int metricId, DateTime day) =>
      (_db.select(_records)
            ..where(
              ($MetricRecordsTable t) =>
                  t.metricId.equals(metricId) &
                  t.date.equals(DayUtils.dayStart(day)),
            ))
          .getSingleOrNull();

  /// 某一天的所有记录。
  Future<List<MetricRecord>> getRecordsOfDay(DateTime day) =>
      (_db.select(_records)
            ..where(
              ($MetricRecordsTable t) => t.date.equals(DayUtils.dayStart(day)),
            ))
          .get();

  /// 某一天的所有记录（响应式，录入页用）。
  Stream<List<MetricRecord>> watchRecordsOfDay(DateTime day) =>
      (_db.select(_records)
            ..where(
              ($MetricRecordsTable t) => t.date.equals(DayUtils.dayStart(day)),
            ))
          .watch();

  /// 某个数据项在时间范围内的记录（画趋势图用），按日期升序。
  Future<List<MetricRecord>> getRecordsBetween(
    int metricId,
    DateTime from,
    DateTime to,
  ) =>
      (_db.select(_records)
            ..where(
              ($MetricRecordsTable t) =>
                  t.metricId.equals(metricId) &
                  t.date.isBetweenValues(
                    DayUtils.dayStart(from),
                    DayUtils.dayEnd(to),
                  ),
            )
            ..orderBy(_recordOrder))
          .get();

  Stream<List<MetricRecord>> watchRecordsBetween(
    int metricId,
    DateTime from,
    DateTime to,
  ) =>
      (_db.select(_records)
            ..where(
              ($MetricRecordsTable t) =>
                  t.metricId.equals(metricId) &
                  t.date.isBetweenValues(
                    DayUtils.dayStart(from),
                    DayUtils.dayEnd(to),
                  ),
            )
            ..orderBy(_recordOrder))
          .watch();

  /// 写入或覆盖某天某个数据项的值。
  ///
  /// 表上有 (metricId, date) 唯一约束，这里用「先更新，没更新到再插入」的方式，
  /// 保证同一天同一个数据项永远只有一行。
  Future<int> upsertRecord({
    required int metricId,
    required DateTime day,
    required double value,
  }) async {
    final DateTime normalized = DayUtils.dayStart(day);
    final int updated = await (_db.update(_records)
          ..where(
            ($MetricRecordsTable t) =>
                t.metricId.equals(metricId) & t.date.equals(normalized),
          ))
        .write(
      MetricRecordsCompanion(
        value: Value<double>(value),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
    if (updated > 0) return updated;
    return _db.into(_records).insert(
          MetricRecordsCompanion.insert(
            metricId: metricId,
            date: normalized,
            value: value,
          ),
        );
  }

  Future<int> updateRecord(int id, MetricRecordsCompanion fields) =>
      (_db.update(_records)..where(($MetricRecordsTable t) => t.id.equals(id)))
          .write(fields.copyWith(updatedAt: Value<DateTime>(DateTime.now())));

  Future<int> deleteRecord(int id) =>
      (_db.delete(_records)..where(($MetricRecordsTable t) => t.id.equals(id)))
          .go();

  /// 清空某天某个数据项的记录（录入页「清除」用）。
  Future<int> deleteRecordOfDay(int metricId, DateTime day) =>
      (_db.delete(_records)
            ..where(
              ($MetricRecordsTable t) =>
                  t.metricId.equals(metricId) &
                  t.date.equals(DayUtils.dayStart(day)),
            ))
          .go();

  Future<int> deleteRecordsOfMetric(int metricId) => (_db.delete(_records)
        ..where(($MetricRecordsTable t) => t.metricId.equals(metricId)))
      .go();

  Future<int> deleteAllRecords() => _db.delete(_records).go();
}
