import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/metric_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/repositories/metric_repository.dart';
import 'package:trace/data/seed/built_in_metrics.dart';

import '../helpers/test_database.dart';

/// 专门验证「5 个内置数据项的种子数据」。
void main() {
  late AppDatabase db;
  late MetricRepository metrics;

  setUp(() {
    db = openTestDatabase();
    metrics = MetricRepository(MetricDao(db));
  });

  tearDown(() => db.close());

  group('内置数据项种子', () {
    test('首次建库自动写入 5 个内置数据项', () async {
      final List<MetricDefinition> defs = await metrics.getDefinitions();

      expect(defs.length, 5);
      expect(
        defs.map((MetricDefinition d) => d.name),
        <String>['入睡时间', '起床时间', '屏幕使用', '饮食热量', '阅读时长'],
      );
      expect(
        defs.map((MetricDefinition d) => d.key),
        <String>[
          BuiltInMetricKeys.sleepTime,
          BuiltInMetricKeys.wakeTime,
          BuiltInMetricKeys.screenTime,
          BuiltInMetricKeys.calories,
          BuiltInMetricKeys.readingTime,
        ],
        reason: '顺序由 sortOrder 决定',
      );
      expect(
        defs.every((MetricDefinition d) => d.isBuiltin),
        isTrue,
        reason: '全部标记为内置',
      );
      expect(
        defs.every((MetricDefinition d) => d.isArchived == false),
        isTrue,
      );
    });

    test('取值类型与单位符合预期', () async {
      final MetricDefinition sleep =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.sleepTime))!;
      expect(sleep.valueType, MetricValueType.clock);
      expect(sleep.unit, '');

      final MetricDefinition screen =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.screenTime))!;
      expect(screen.valueType, MetricValueType.duration);
      expect(screen.unit, '分钟');
      expect(screen.targetValue, 180);

      final MetricDefinition calories =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.calories))!;
      expect(calories.valueType, MetricValueType.number);
      expect(calories.unit, 'kcal');

      final MetricDefinition reading =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
      expect(reading.valueType, MetricValueType.duration);
      expect(reading.unit, '分钟');
      expect(reading.targetValue, 30);
    });

    test('颜色与图标都已预置（界面直接用）', () async {
      final List<MetricDefinition> defs = await metrics.getDefinitions();
      for (final MetricDefinition d in defs) {
        expect(d.colorHex, isNot(0), reason: '${d.name} 应该有配色');
        expect(d.iconKey, isNotEmpty, reason: '${d.name} 应该有图标标识');
      }
    });

    test('重复补种不会产生重复数据（幂等）', () async {
      await metrics.ensureBuiltInMetrics();
      await metrics.ensureBuiltInMetrics();
      expect((await metrics.getDefinitions()).length, 5);
    });

    test('用户删掉内置项后，可以一键补回', () async {
      final MetricDefinition def =
          (await metrics.getDefinitionByKey(BuiltInMetricKeys.calories))!;
      await metrics.removeMetric(def.id);
      expect((await metrics.getDefinitions()).length, 4);

      await metrics.ensureBuiltInMetrics();
      expect((await metrics.getDefinitions()).length, 5);
      expect(
        await metrics.getDefinitionByKey(BuiltInMetricKeys.calories),
        isNotNull,
      );
    });

    test('种子定义本身：5 项、key 唯一', () {
      expect(kBuiltInMetrics.length, 5);
      final Set<String> keys =
          kBuiltInMetrics.map((BuiltInMetric m) => m.key).toSet();
      expect(keys.length, 5, reason: 'key 不能重复');
    });
  });
}
