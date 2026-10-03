import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/core/theme/app_motion.dart';
import 'package:trace/data/dao/goal_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/data/repositories/goal_repository.dart';
import 'package:trace/features/goals/presentation/widgets/goal_card.dart';
import 'package:trace/features/home/presentation/widgets/section_tile.dart';

void main() {
  late AppDatabase db;
  late GoalRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = GoalRepository(GoalDao(db));
  });

  tearDown(() => db.close());

  /// 有界等待（不用 pumpAndSettle：加载动画和输入框光标都是无限动画）。
  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// 收尾：先卸载整棵树，再让 drift 取消查询流时排的定时器跑完。
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// 打开 App 并进入「目标」页（主页第 2 个板块）。
  Future<void> openGoalsPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(SectionTile).at(1));
    await settle(tester);
  }

  testWidgets('空状态 → 新建目标 → 出现在列表', (WidgetTester tester) async {
    await openGoalsPage(tester);

    expect(find.text('还没有今日目标'), findsOneWidget);
    expect(find.byType(GoalCard), findsNothing);

    await tester.tap(find.text('新增目标'));
    await settle(tester);
    expect(find.text('新建目标'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '今天读完一章');
    await tester.enterText(find.byType(TextField).last, '从第 3 章开始');
    await tester.tap(find.text('保存'));
    await settle(tester, frames: 12);

    expect(find.text('今天读完一章'), findsOneWidget);
    expect(find.text('从第 3 章开始'), findsOneWidget);
    expect(find.text('共 1 个 · 已完成 0 个'), findsOneWidget);

    final List<Goal> goals = await repo.getByCategory(GoalCategory.today);
    expect(goals.length, 1);
    expect(goals.single.title, '今天读完一章');
    expect(goals.single.status, GoalStatus.active);

    await disposeTree(tester);
  });

  testWidgets('三个时间尺度互相独立', (WidgetTester tester) async {
    await repo.add(
      title: '今年读完 24 本书',
      category: GoalCategory.thisYear,
    );
    await repo.add(
      title: '成为能持续输出的人',
      category: GoalCategory.life,
    );
    await openGoalsPage(tester);

    // 默认停在「今日目标」，看不到另外两类
    expect(find.text('今年读完 24 本书'), findsNothing);
    expect(find.text('成为能持续输出的人'), findsNothing);
    expect(find.text('还没有今日目标'), findsOneWidget);

    await tester.tap(find.text('今年目标'));
    await settle(tester);
    expect(find.text('今年读完 24 本书'), findsOneWidget);
    expect(find.text('成为能持续输出的人'), findsNothing);

    await tester.tap(find.text('人生目标'));
    await settle(tester);
    expect(find.text('成为能持续输出的人'), findsOneWidget);
    expect(find.text('今年读完 24 本书'), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('进度显示与汇总联动', (WidgetTester tester) async {
    await repo.add(
      title: '学完 Flutter',
      category: GoalCategory.today,
      progress: 0.5,
    );
    await openGoalsPage(tester);

    // 卡片上的百分比 + 汇总环上的平均进度
    expect(find.text('50%'), findsNWidgets(2));
    expect(find.text('共 1 个 · 已完成 0 个'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('左滑删除后可以撤销', (WidgetTester tester) async {
    await repo.add(title: '临时目标', category: GoalCategory.today);
    await openGoalsPage(tester);
    expect(find.text('临时目标'), findsOneWidget);

    await tester.drag(find.byType(GoalCard).first, const Offset(-140, 0));
    await settle(tester, frames: 12);

    expect(find.text('临时目标'), findsNothing);
    expect(find.text('撤销'), findsOneWidget);
    expect(await repo.getByCategory(GoalCategory.today), isEmpty);

    await tester.tap(find.text('撤销'));
    await settle(tester, frames: 10);

    expect(find.text('临时目标'), findsOneWidget);
    expect((await repo.getByCategory(GoalCategory.today)).length, 1);

    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    await disposeTree(tester);
  });

  testWidgets('切换时间尺度时内容交叉淡入（不是硬切）', (WidgetTester tester) async {
    await repo.add(title: '今年读完 24 本书', category: GoalCategory.thisYear);
    await openGoalsPage(tester);

    expect(find.text('今日目标列表'), findsWidgets);
    expect(find.text('今年目标列表'), findsNothing);

    await tester.tap(find.text('今年目标'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // 交叉淡入进行中：新旧两块的标题同时挂在树上
    expect(find.text('今日目标列表'), findsWidgets, reason: '旧内容还在淡出');
    expect(find.text('今年目标列表'), findsWidgets, reason: '新内容已经开始淡入');

    await tester.pump(AppMotion.medium + const Duration(milliseconds: 80));
    expect(find.text('今日目标列表'), findsNothing, reason: '动画结束后旧内容应被移除');
    expect(find.text('今年目标列表'), findsWidgets);
    expect(find.text('今年读完 24 本书'), findsWidgets);

    await disposeTree(tester);
  });
}
