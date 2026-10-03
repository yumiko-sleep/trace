import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/metric_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/models/stats.dart';
import 'package:trace/data/repositories/metric_repository.dart';
import 'package:trace/data/seed/built_in_metrics.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MetricRepository metrics;

  setUp(() {
    db = openTestDatabase();
    metrics = MetricRepository(MetricDao(db));
  });

  tearDown(() => db.close());

  group('MetricRepository', () {
    test('同一数据项同一天写入两次 → 只有一条记录，值被覆盖', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;

      await metrics.setValue(
        metricId: def.id,
        day: DateTime(2026, 10, 3, 8),
        value: 10,
      );
      await metrics.setValue(
        metricId: def.id,
        day: DateTime(2026, 10, 3, 23, 30),
        value: 25,
      );

      final List<MetricTrendPoint> trend =
          await metrics.getTrend(def.id, days: 1, end: DateTime(2026, 10, 3));
      expect(trend.length, 1, reason: '(metricId, date) 唯一约束应保证不重复');
      expect(trend.single.value, 25);
      expect(trend.single.date, DateTime(2026, 10, 3));
    });

    test('setValueByKey 直接按内置 key 写值', () async {
      await metrics.setValueByKey(
        key: BuiltInMetricKeys.sleepTime,
        day: DateTime(2026, 10, 3),
        value: 1410, // 23:30
      );

      final MetricTrendPoint? point = await metrics.getTrendByKey(
        BuiltInMetricKeys.sleepTime,
        days: 1,
        end: DateTime(2026, 10, 3),
      );
      expect(point, isNotNull);
      expect(point!.value, 1410);
    });

    test('valuesOfDay 返回当天所有数据项的值', () async {
      final DateTime day = DateTime(2026, 10, 3);
      await metrics.setValueByKey(
        key: BuiltInMetricKeys.calories,
        day: day,
        value: 1850,
      );
      await metrics.setValueByKey(
        key: BuiltInMetricKeys.screenTime,
        day: day,
        value: 210,
      );

      final Map<int, double> values = await metrics.valuesOfDay(day);
      expect(values.length, 2);
      expect(values.values, containsAll(<double>[1850, 210]));
    });

    test('getTrend 只返回时间窗口内的记录，且按日期升序', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      final DateTime today = DateTime(2026, 10, 10);

      await metrics.setValue(metricId: def.id, day: DateTime(2026, 10, 1), value: 5);
      await metrics.setValue(metricId: def.id, day: DateTime(2026, 10, 8), value: 20);
      await metrics.setValue(metricId: def.id, day: DateTime(2026, 10, 9), value: 30);
      await metrics.setValue(metricId: def.id, day: DateTime(2026, 10, 10), value: 40);

      final List<MetricTrendPoint> week =
          await metrics.getTrend(def.id, days: 3, end: today);
      expect(week.length, 3);
      expect(week.map((MetricTrendPoint p) => p.value), <double>[20, 30, 40]);
    });

    test('summarize 计算记录天数、平均值与最优一天', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      final DateTime today = DateTime(2026, 10, 3);

      await metrics.setValue(metricId: def.id, day: DateTime(2026, 10, 1), value: 10);
      await metrics.setValue(metricId: def.id, day: DateTime(2026, 10, 2), value: 20);
      await metrics.setValue(metricId: def.id, day: DateTime(2026, 10, 3), value: 30);

      final MetricSummary summary =
          await metrics.summarize(def.id, days: 7, end: today);
      expect(summary.recordedDays, 3);
      expect(summary.totalDays, 7);
      expect(summary.average, closeTo(20, 0.0001));
      expect(summary.best!.value, 30, reason: '默认数值越大越好');

      final MetricSummary lower =
          await metrics.summarize(def.id, days: 7, end: today, lowerIsBetter: true);
      expect(lower.best!.value, 10, reason: '屏幕时间这类指标越小越好');
    });

    test('没有任何记录时 summarize 返回空结果而不是报错', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.calories))!;
      final MetricSummary summary = await metrics.summarize(def.id, days: 7);
      expect(summary.recordedDays, 0);
      expect(summary.average, isNull);
      expect(summary.best, isNull);
    });

    test('新增自定义数据项', () async {
      await metrics.addCustomMetric(
        name: '伏完撑',
        valueType: MetricValueType.number,
        unit: '个',
        colorHex: 0xFFF26D6D,
      );

      final List<MetricDefinition> defs = await metrics.getDefinitions();
      expect(defs.length, 6);

      final MetricDefinition custom =
          defs.firstWhere((MetricDefinition d) => d.name == '伏完撑');
      expect(custom.isBuiltin, isFalse);
      expect(custom.key, startsWith('custom_'));
      expect(custom.unit, '个');
      expect(custom.sortOrder, 5, reason: '排在最后一个内置项之后');
    });

    test('归档后默认列表不再返回，但历史记录还在', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.calories))!;
      await metrics.setValue(
        metricId: def.id,
        day: DateTime(2026, 10, 3),
        value: 2000,
      );

      await metrics.archiveMetric(def.id);
      expect(
        (await metrics.getDefinitions()).map((MetricDefinition d) => d.key),
        isNot(contains(BuiltInMetricKeys.calories)),
      );
      expect(
        (await metrics.getDefinitions(includeArchived: true))
            .map((MetricDefinition d) => d.key),
        contains(BuiltInMetricKeys.calories),
      );

      // 历史记录仍在
      final List<MetricTrendPoint> trend =
          await metrics.getTrend(def.id, days: 1, end: DateTime(2026, 10, 3));
      expect(trend.length, 1);
    });

    test('删除数据项会级联删掉它的历史记录', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.wakeTime))!;
      await metrics.setValue(
        metricId: def.id,
        day: DateTime(2026, 10, 3),
        value: 420,
      );
      expect(await metrics.getValue(def.id, DateTime(2026, 10, 3)), isNotNull);

      await metrics.removeMetric(def.id);
      expect(await metrics.getValue(def.id, DateTime(2026, 10, 3)), isNull);
    });

    test('watchValuesOfDay 响应式返回当天所有数据项的值', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final MetricDefinition reading =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      final MetricDefinition calories =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.calories))!;

      await metrics.setValue(metricId: reading.id, day: day, value: 25);
      await metrics.setValue(metricId: calories.id, day: day, value: 1800);

      final Map<int, double> values = await metrics.watchValuesOfDay(day).first;
      expect(values[reading.id], 25);
      expect(values[calories.id], 1800);
      expect(values.length, 2);
    });

    test('clearValue 只清掉指定数据项当天的记录', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final MetricDefinition reading =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      final MetricDefinition calories =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.calories))!;

      await metrics.setValue(metricId: reading.id, day: day, value: 25);
      await metrics.setValue(metricId: calories.id, day: day, value: 1800);

      await metrics.clearValue(reading.id, day);

      expect(await metrics.getValue(reading.id, day), isNull);
      expect(await metrics.getValue(calories.id, day), isNotNull);
    });

    test('unarchiveMetric 把归档的数据项恢复回列表', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.wakeTime))!;

      await metrics.archiveMetric(def.id);
      expect(
        (await metrics.getDefinitions()).map((MetricDefinition d) => d.id),
        isNot(contains(def.id)),
      );

      await metrics.unarchiveMetric(def.id);
      expect(
        (await metrics.getDefinitions()).map((MetricDefinition d) => d.id),
        contains(def.id),
      );
    });

    test('watchTrendPoints 直接产出趋势点', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      await metrics.setValue(
        metricId: def.id,
        day: DateTime(2026, 10, 3),
        value: 42,
      );

      final List<MetricTrendPoint> points = await metrics
          .watchTrendPoints(def.id, days: 7, end: DateTime(2026, 10, 3))
          .first;
      expect(points.length, 1);
      expect(points.single.value, 42);
    });
  });
}
