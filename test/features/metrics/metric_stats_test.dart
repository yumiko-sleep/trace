import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/metric_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/models/stats.dart';
import 'package:trace/data/repositories/metric_repository.dart';
import 'package:trace/data/seed/built_in_metrics.dart';
import 'package:trace/features/metrics/domain/metric_stats.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MetricRepository metrics;

  setUp(() {
    db = openTestDatabase();
    metrics = MetricRepository(MetricDao(db));
  });

  tearDown(() => db.close());

  MetricTrendPoint point(int day, double value) =>
      MetricTrendPoint(date: DateTime(2026, 10, day), value: value);

  group('数值格式化', () {
    test('时间点 → HH:mm，时长 → 小时/分钟，数值 → 带单位', () async {
      final MetricDefinition clock =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.sleepTime))!;
      final MetricDefinition duration =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      final MetricDefinition calories =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.calories))!;

      expect(formatMetricValue(clock, 1410), '23:30');
      expect(formatMetricValue(duration, 90), '1小时30分');
      expect(formatMetricValue(duration, 45), '45分钟');
      expect(formatMetricValue(calories, 1850), '1850 kcal');
    });

    test('坐标轴短文本：分钟数少于 2 小时用 m，超过用 h', () async {
      final MetricDefinition duration =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      expect(formatMetricShort(duration, 45), '45m');
      expect(formatMetricShort(duration, 90), '90m');
      expect(formatMetricShort(duration, 150), '2.5h');
    });

    test('trimNumber 去掉多余小数', () {
      expect(trimNumber(25), '25');
      expect(trimNumber(25.0), '25');
      expect(trimNumber(25.5), '25.5');
    });

    test('屏幕使用这类指标越小越好', () async {
      final MetricDefinition screen =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.screenTime))!;
      final MetricDefinition reading =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      expect(metricLowerIsBetter(screen), isTrue);
      expect(metricLowerIsBetter(reading), isFalse);
    });
  });

  group('computeMetricStats', () {
    test('没有记录时返回空结果', () {
      final MetricStats stats = computeMetricStats(
        points: const <MetricTrendPoint>[],
        totalDays: 7,
        target: 30,
      );
      expect(stats.isEmpty, isTrue);
      expect(stats.average, isNull);
      expect(stats.best, isNull);
      expect(stats.coverage, 0);
      expect(stats.achievedRate, isNull);
    });

    test('计算记录天数、覆盖率、平均值与最优一天', () {
      final MetricStats stats = computeMetricStats(
        points: <MetricTrendPoint>[
          point(1, 10),
          point(2, 20),
          point(3, 30),
        ],
        totalDays: 7,
        target: 20,
      );
      expect(stats.recordedDays, 3);
      expect(stats.totalDays, 7);
      expect(stats.sum, 60);
      expect(stats.average, closeTo(20, 0.0001));
      expect(stats.best!.value, 30);
      expect(stats.coverage, closeTo(3 / 7, 0.0001));
    });

    test('达标率按「有记录的天数」算，而不是按窗口天数', () {
      final MetricStats stats = computeMetricStats(
        points: <MetricTrendPoint>[
          point(1, 10), // 未达标
          point(2, 30), // 达标
          point(3, 40), // 达标
        ],
        totalDays: 7,
        target: 30,
      );
      expect(stats.achievedDays, 2);
      expect(stats.achievedRate, closeTo(2 / 3, 0.0001));
    });

    test('越小越好的指标：最优一天取最小值，达标判断反过来', () {
      final MetricStats stats = computeMetricStats(
        points: <MetricTrendPoint>[
          point(1, 200),
          point(2, 90),
          point(3, 150),
        ],
        totalDays: 7,
        target: 120,
        lowerIsBetter: true,
      );
      expect(stats.best!.value, 90);
      expect(stats.achievedDays, 1);
    });

    test('连续记录天数：中间断档就停止计数', () {
      final MetricStats stats = computeMetricStats(
        points: <MetricTrendPoint>[
          point(1, 10),
          point(2, 20),
          // 3 号断档
          point(4, 30),
          point(5, 40),
        ],
        totalDays: 7,
      );
      expect(stats.streak, 2, reason: '从 5 号往前数只有 4、5 号连着');
    });

    test('每天都记录时连续天数等于记录天数', () {
      final MetricStats stats = computeMetricStats(
        points: <MetricTrendPoint>[
          point(1, 10),
          point(2, 20),
          point(3, 30),
        ],
        totalDays: 7,
      );
      expect(stats.streak, 3);
    });
  });

  group('metricAchieved', () {
    test('按数据项的目标值判断是否达标', () async {
      final MetricDefinition reading =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      expect(metricAchieved(reading, 30), isTrue);
      expect(metricAchieved(reading, 29), isFalse);

      final MetricDefinition screen =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.screenTime))!;
      expect(metricAchieved(screen, 180), isTrue);
      expect(metricAchieved(screen, 181), isFalse);
    });

    test('没设目标值的自定义项永远不算达标', () async {
      final int id = await metrics.addCustomMetric(
        name: '喝水量',
        valueType: MetricValueType.number,
        unit: '杯',
      );
      final MetricDefinition custom = (await metrics.getDefinitionById(id))!;
      expect(custom.targetValue, isNull);
      expect(metricAchieved(custom, 8), isFalse);
    });
  });
}
