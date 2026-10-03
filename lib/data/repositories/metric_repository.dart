import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../dao/metric_dao.dart';
import '../db/app_database.dart';
import '../models/enums.dart';
import '../models/stats.dart';

/// 数据板块仓储：数据项管理 + 每日数值写入 + 趋势统计。
class MetricRepository {
  MetricRepository(this._dao);

  final MetricDao _dao;

  // ---------------- 数据项 ----------------

  Future<List<MetricDefinition>> getDefinitions({bool includeArchived = false}) =>
      _dao.getDefinitions(includeArchived: includeArchived);

  Stream<List<MetricDefinition>> watchDefinitions({
    bool includeArchived = false,
  }) =>
      _dao.watchDefinitions(includeArchived: includeArchived);

  Future<MetricDefinition?> getDefinitionById(int id) =>
      _dao.getDefinitionById(id);

  Future<MetricDefinition?> getDefinitionByKey(String key) =>
      _dao.getDefinitionByKey(key);

  /// 新增自定义数据项。
  Future<int> addCustomMetric({
    required String name,
    required MetricValueType valueType,
    String unit = '',
    int colorHex = 0xFF3DDC97,
    String iconKey = '',
    double? targetValue,
  }) async {
    final List<MetricDefinition> all =
        await _dao.getDefinitions(includeArchived: true);
    final int sortOrder = all.isEmpty
        ? 0
        : all.map((MetricDefinition d) => d.sortOrder).reduce(math.max) + 1;
    return _dao.insertDefinition(
      MetricDefinitionsCompanion.insert(
        // 自定义项用时间戳保证 key 唯一
        key: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        valueType: valueType,
        unit: Value<String>(unit),
        colorHex: Value<int>(colorHex),
        iconKey: Value<String>(iconKey),
        targetValue: Value<double?>(targetValue),
        isBuiltin: const Value<bool>(false),
        sortOrder: Value<int>(sortOrder),
      ),
    );
  }

  Future<int> renameMetric(int id, String name) => _dao.updateDefinition(
        id,
        MetricDefinitionsCompanion(name: Value<String>(name.trim())),
      );

  Future<int> updateMetric({
    required int id,
    String? name,
    String? unit,
    int? colorHex,
    String? iconKey,
    double? targetValue,
    bool clearTarget = false,
  }) =>
      _dao.updateDefinition(
        id,
        MetricDefinitionsCompanion(
          name: name == null ? const Value.absent() : Value<String>(name.trim()),
          unit: unit == null ? const Value.absent() : Value<String>(unit),
          colorHex:
              colorHex == null ? const Value.absent() : Value<int>(colorHex),
          iconKey:
              iconKey == null ? const Value.absent() : Value<String>(iconKey),
          targetValue: clearTarget
              ? const Value<double?>(null)
              : (targetValue == null
                  ? const Value.absent()
                  : Value<double?>(targetValue)),
        ),
      );

  /// 归档（保留历史记录，不物理删除）。
  Future<int> archiveMetric(int id, {bool archived = true}) =>
      _dao.archiveDefinition(id, archived: archived);

  /// 恢复一个被归档的数据项。
  Future<int> unarchiveMetric(int id) => _dao.archiveDefinition(id, archived: false);

  Future<int> removeMetric(int id) => _dao.deleteDefinition(id);

  Future<void> ensureBuiltInMetrics() => _dao.ensureBuiltInMetrics();

  // ---------------- 每日数值 ----------------

  /// 写入（或覆盖）某天某个数据项的值。
  Future<void> setValue({
    required int metricId,
    required DateTime day,
    required double value,
  }) =>
      _dao.upsertRecord(metricId: metricId, day: day, value: value);

  /// 按内置 key 写值，例如 [BuiltInMetricKeys.sleepTime]。
  Future<void> setValueByKey({
    required String key,
    required DateTime day,
    required double value,
  }) async {
    final MetricDefinition? def = await _dao.getDefinitionByKey(key);
    if (def == null) {
      throw StateError('未找到数据项：$key（可能还没有补种内置数据项）');
    }
    await _dao.upsertRecord(metricId: def.id, day: day, value: value);
  }

  Future<MetricRecord?> getValue(int metricId, DateTime day) =>
      _dao.getRecord(metricId, day);

  /// 某天所有数据项的值，key 为 metricId。
  Future<Map<int, double>> valuesOfDay(DateTime day) async {
    final List<MetricRecord> rows = await _dao.getRecordsOfDay(day);
    return <int, double>{for (final MetricRecord r in rows) r.metricId: r.value};
  }

  Future<int> removeValue(int recordId) => _dao.deleteRecord(recordId);

  // ---------------- 趋势 / 统计 ----------------

  /// 最近 [days] 天某个数据项的趋势点（缺记录的日子不补 0，由图表层决定怎么画）。
  Future<List<MetricTrendPoint>> getTrend(
    int metricId, {
    required int days,
    DateTime? end,
  }) async {
    final DateTime to = DayUtils.dayStart(end ?? DateTime.now());
    final DateTime from = to.subtract(Duration(days: days - 1));
    final List<MetricRecord> records =
        await _dao.getRecordsBetween(metricId, from, to);
    return records
        .map((MetricRecord r) =>
            MetricTrendPoint(date: r.date, value: r.value))
        .toList();
  }

  Stream<List<MetricRecord>> watchTrend(
    int metricId, {
    required int days,
    DateTime? end,
  }) {
    final DateTime to = DayUtils.dayStart(end ?? DateTime.now());
    return _dao.watchRecordsBetween(
      metricId,
      to.subtract(Duration(days: days - 1)),
      to,
    );
  }

  /// 趋势点的响应式版本（图表直接消费）。
  Stream<List<MetricTrendPoint>> watchTrendPoints(
    int metricId, {
    required int days,
    DateTime? end,
  }) =>
      watchTrend(metricId, days: days, end: end).map(
        (List<MetricRecord> records) => records
            .map((MetricRecord r) =>
                MetricTrendPoint(date: r.date, value: r.value))
            .toList(),
      );

  /// 某天所有数据项的值（响应式），key 为 metricId。
  Stream<Map<int, double>> watchValuesOfDay(DateTime day) => _dao
      .watchRecordsOfDay(day)
      .map((List<MetricRecord> rows) => <int, double>{
            for (final MetricRecord r in rows) r.metricId: r.value,
          });

  /// 清除某天某个数据项的值。
  Future<int> clearValue(int metricId, DateTime day) =>
      _dao.deleteRecordOfDay(metricId, day);

  Future<MetricTrendPoint?> getTrendByKey(
    String key, {
    required int days,
    DateTime? end,
  }) async {
    final MetricDefinition? def = await _dao.getDefinitionByKey(key);
    if (def == null) return null;
    final List<MetricTrendPoint> points =
        await getTrend(def.id, days: days, end: end);
    return points.isEmpty ? null : points.last;
  }

  /// 统计最近 [days] 天：记录天数、覆盖率、平均值、最优一天。
  Future<MetricSummary> summarize(
    int metricId, {
    required int days,
    DateTime? end,
    bool lowerIsBetter = false,
  }) async {
    final List<MetricTrendPoint> points =
        await getTrend(metricId, days: days, end: end);
    if (points.isEmpty) {
      return MetricSummary(
        recordedDays: 0,
        totalDays: days,
        average: null,
        best: null,
      );
    }
    final double sum =
        points.fold<double>(0, (double acc, MetricTrendPoint p) => acc + p.value);
    MetricTrendPoint best = points.first;
    for (final MetricTrendPoint p in points) {
      final bool better =
          lowerIsBetter ? p.value < best.value : p.value > best.value;
      if (better) best = p;
    }
    return MetricSummary(
      recordedDays: points.length,
      totalDays: days,
      average: sum / points.length,
      best: best,
    );
  }
}
