import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/day_utils.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/metric_repository.dart';
import '../domain/metric_stats.dart';

/// ============================================================
/// 「数据」板块的状态与操作。
///
/// UI 只依赖这里的 Provider，DAO 细节全部关在 Repository 之后。
/// ============================================================

/// 全部未归档的数据项（内置 5 个 + 自定义）。
final AutoDisposeStreamProvider<List<MetricDefinition>>
    metricDefinitionsProvider =
    StreamProvider.autoDispose<List<MetricDefinition>>((Ref ref) {
  return ref.watch(metricRepositoryProvider).watchDefinitions();
});

/// 正在看趋势图的数据项（null = 用第一个）。
final StateProvider<int?> selectedMetricIdProvider =
    StateProvider<int?>((Ref ref) => null);

/// 趋势图的时间窗口。
final StateProvider<MetricRange> metricRangeProvider =
    StateProvider<MetricRange>((Ref ref) => MetricRange.week);

/// 录入页当前正在填的日期（默认今天，可以往前翻补录）。
final StateProvider<DateTime> metricEntryDayProvider =
    StateProvider<DateTime>((Ref ref) => DayUtils.dayStart(DateTime.now()));

/// 某一天已有记录的值，key 为 metricId。
final AutoDisposeStreamProvider<Map<int, double>> dayMetricValuesProvider =
    StreamProvider.autoDispose<Map<int, double>>((Ref ref) {
  final DateTime day = ref.watch(metricEntryDayProvider);
  return ref.watch(metricRepositoryProvider).watchValuesOfDay(day);
});

/// 当前趋势图对应的数据项定义。
final Provider<MetricDefinition?> selectedMetricProvider =
    Provider<MetricDefinition?>((Ref ref) {
  final List<MetricDefinition> defs =
      ref.watch(metricDefinitionsProvider).valueOrNull ??
          const <MetricDefinition>[];
  if (defs.isEmpty) {
    return null;
  }
  final int? id = ref.watch(selectedMetricIdProvider);
  for (final MetricDefinition d in defs) {
    if (d.id == id) {
      return d;
    }
  }
  return defs.first;
});

/// 当前数据项在窗口内的趋势点。
final AutoDisposeStreamProvider<List<MetricTrendPoint>> metricTrendProvider =
    StreamProvider.autoDispose<List<MetricTrendPoint>>((Ref ref) {
  final MetricDefinition? def = ref.watch(selectedMetricProvider);
  if (def == null) {
    return Stream<List<MetricTrendPoint>>.value(const <MetricTrendPoint>[]);
  }
  final int days = ref.watch(metricRangeProvider).days;
  return ref
      .watch(metricRepositoryProvider)
      .watchTrendPoints(def.id, days: days);
});

/// 当前数据项在窗口内的统计结果。
final Provider<MetricStats?> metricStatsProvider =
    Provider<MetricStats?>((Ref ref) {
  final MetricDefinition? def = ref.watch(selectedMetricProvider);
  if (def == null) return null;
  final List<MetricTrendPoint>? points =
      ref.watch(metricTrendProvider).valueOrNull;
  if (points == null) {
    return null;
  }
  return computeMetricStats(
    points: points,
    totalDays: ref.watch(metricRangeProvider).days,
    target: def.targetValue,
    lowerIsBetter: metricLowerIsBetter(def),
  );
});

/// 录入页的进度：这一天填了几项 / 共几项。
final Provider<DayMetricProgress> dayMetricProgressProvider =
    Provider<DayMetricProgress>((Ref ref) {
  final List<MetricDefinition> defs =
      ref.watch(metricDefinitionsProvider).valueOrNull ??
          const <MetricDefinition>[];
  final Map<int, double> values =
      ref.watch(dayMetricValuesProvider).valueOrNull ?? const <int, double>{};
  return DayMetricProgress(
    recorded: defs.where((MetricDefinition d) => values.containsKey(d.id)).length,
    total: defs.length,
  );
});

/// 数据板块的写操作。
final Provider<MetricActions> metricActionsProvider =
    Provider<MetricActions>((Ref ref) => MetricActions(ref));

class MetricActions {
  MetricActions(this._ref);

  final Ref _ref;

  MetricRepository get _repo => _ref.read(metricRepositoryProvider);

  /// 写入（覆盖）某天某个数据项的值。
  Future<void> setValue({
    required int metricId,
    required DateTime day,
    required double value,
  }) =>
      _repo.setValue(metricId: metricId, day: day, value: value);

  /// 清空某天某个数据项的值。
  Future<int> clearValue({required int metricId, required DateTime day}) =>
      _repo.clearValue(metricId, day);

  Future<int> addCustom({
    required String name,
    required MetricValueType valueType,
    String unit = '',
    int colorHex = 0xFF3DDC97,
    double? targetValue,
  }) =>
      _repo.addCustomMetric(
        name: name,
        valueType: valueType,
        unit: unit,
        colorHex: colorHex,
        targetValue: targetValue,
      );

  Future<int> update({
    required int id,
    String? name,
    String? unit,
    int? colorHex,
    double? targetValue,
    bool clearTarget = false,
  }) =>
      _repo.updateMetric(
        id: id,
        name: name,
        unit: unit,
        colorHex: colorHex,
        targetValue: targetValue,
        clearTarget: clearTarget,
      );

  Future<int> archive(int id) => _repo.archiveMetric(id);

  Future<int> unarchive(int id) => _repo.unarchiveMetric(id);

  /// 物理删除（连同历史记录，仅自定义数据项允许）。
  Future<int> remove(int id) => _repo.removeMetric(id);

  /// 误删 / 全部归档后，一键把 5 个内置数据项补回来。
  Future<void> restoreBuiltIns() => _repo.ensureBuiltInMetrics();
}
