import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/data/dao/metric_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/data/repositories/metric_repository.dart';
import 'package:trace/data/seed/built_in_metrics.dart';
import 'package:trace/features/home/presentation/widgets/section_tile.dart';

void main() {
  late AppDatabase db;
  late MetricRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = MetricRepository(MetricDao(db));
  });

  tearDown(() => db.close());

  /// 有界等待（不用 pumpAndSettle：加载动画和输入框光标都是无限动画）。
  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// 收尾：先卸载整棵树，让 drift 取消查询流时排的定时器跑完。
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// 打开 App 并进入「数据」页（主页第 4 个板块，位于第二行）。
  Future<void> openMetricsPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 测试视口只有 600px 高，第二行的入口在折叠线以下，必须先滚动到可见再点
    final Finder tile = find.byType(SectionTile).at(3);
    await tester.ensureVisible(tile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(tile);
    await settle(tester);
  }

  testWidgets('录入一个值 → 出现在当天列表并写进数据库', (WidgetTester tester) async {
    await openMetricsPage(tester);

    expect(find.textContaining('记录今天'), findsOneWidget);
    expect(find.text('还差 5 项，点一行填一个'), findsOneWidget);
    expect(find.textContaining('这段时间还没有记录'), findsOneWidget);

    // 点「阅读时长」这一行
    final Finder row = find.text('阅读时长').first;
    await tester.ensureVisible(row);
    await settle(tester, frames: 2);
    await tester.tap(row);
    await settle(tester, frames: 8);

    // 弹窗里填 25 并保存
    expect(find.text('常用'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '25');
    await settle(tester, frames: 2);
    await tester.tap(find.text('保存'));
    await settle(tester, frames: 12);

    // 列表里出现 25 分钟，进度同步
    expect(find.text('25分钟'), findsWidgets);
    expect(find.text('还差 4 项，点一行填一个'), findsOneWidget);

    final MetricDefinition reading =
        (await repo.getDefinitionByKey(BuiltInMetricKeys.readingTime))!;
    final MetricRecord? record =
        await repo.getValue(reading.id, DateTime.now());
    expect(record, isNotNull);
    expect(record!.value, 25);

    // 趋势区：先选中刚才记录的数据项，再切换周 / 月 / 年
    final Finder chip = find.text('阅读时长').last;
    await tester.ensureVisible(chip);
    await settle(tester, frames: 2);
    await tester.tap(chip);
    await settle(tester, frames: 6);
    expect(find.text('阅读时长 · 最近 7 天'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);

    final Finder month = find.text('月');
    await tester.ensureVisible(month);
    await settle(tester, frames: 2);
    await tester.tap(month);
    await settle(tester, frames: 6);
    expect(find.text('阅读时长 · 最近 30 天'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('新增自定义数据项会立刻出现在列表里', (WidgetTester tester) async {
    await openMetricsPage(tester);

    await tester.tap(find.text('新增数据项'));
    await settle(tester, frames: 8);
    expect(find.text('类型'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '喝水量');
    await settle(tester, frames: 2);
    await tester.tap(find.text('保存'));
    await settle(tester, frames: 12);

    expect(find.text('喝水量'), findsWidgets);
    expect(find.text('还差 6 项，点一行填一个'), findsOneWidget);

    final List<MetricDefinition> defs = await repo.getDefinitions();
    expect(defs.length, 6);
    expect(
      defs.where((MetricDefinition d) => d.name == '喝水量').single.isBuiltin,
      isFalse,
    );

    await disposeTree(tester);
  });

  testWidgets('管理弹窗列出全部数据项并提供新增入口', (WidgetTester tester) async {
    await openMetricsPage(tester);

    final Finder manage = find.text('管理');
    await tester.ensureVisible(manage);
    await settle(tester, frames: 2);
    await tester.tap(manage);
    await settle(tester, frames: 8);

    expect(find.text('管理数据项'), findsOneWidget);
    expect(find.text('共 5 项 · 点一项可以改名、设目标值或归档'), findsOneWidget);
    expect(find.text('内置'), findsNWidgets(5));

    await disposeTree(tester);
  });
}
