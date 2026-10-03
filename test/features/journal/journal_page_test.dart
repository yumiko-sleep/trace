import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/core/widgets/diary_media.dart' show PillActionButton;
import 'package:trace/data/dao/journal_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/data/repositories/journal_repository.dart';
import 'package:trace/features/home/presentation/widgets/section_tile.dart';
import 'package:trace/features/journal/presentation/widgets/journal_log_card.dart';
import 'package:trace/features/journal/presentation/widgets/journal_plan_card.dart';

void main() {
  late AppDatabase db;
  late JournalRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = JournalRepository(JournalDao(db));
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

  /// 打开 App 并进入「日志」页（主页第 5 个板块，位于第二行）。
  Future<void> openJournalPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final Finder tile = find.byType(SectionTile).at(4);
    await tester.ensureVisible(tile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(tile);
    await settle(tester);
  }

  /// 滚动到目标位置再点，避开 600px 高的测试视口。
  Future<void> tapAt(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester, frames: 2);
    await tester.tap(finder);
    await settle(tester, frames: 8);
  }

  /// 点右下角「记录今天」悬浮按钮（它总在屏幕内，不需要滚动）。
  Future<void> tapRecordFab(WidgetTester tester) async {
    await tester.tap(find.byType(PillActionButton));
    await settle(tester, frames: 10);
  }

  testWidgets('新建计划 → 记录今天 → 写复盘，复盘不会被记录覆盖', (WidgetTester tester) async {
    await openJournalPage(tester);

    expect(find.text('还没有学习计划'), findsOneWidget);
    expect(find.text('还没有学习记录'), findsOneWidget);

    // ---------- 新建学习计划 ----------
    await tapAt(tester, find.text('新建计划').first);
    expect(find.text('新建学习计划'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '数学一轮复习');
    await settle(tester, frames: 2);
    await tester.tap(find.text('保存'));
    await settle(tester, frames: 12);

    expect(find.byType(JournalPlanCard), findsOneWidget);
    expect(find.text('数学一轮复习'), findsWidgets);
    final List<JournalPlan> plans = await repo.getPlans(JournalType.study);
    expect(plans.length, 1);
    expect(plans.single.title, '数学一轮复习');
    expect(plans.single.isActive, isTrue);

    // ---------- 记录今天 ----------
    await tapRecordFab(tester);
    expect(find.text('记录学习'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '刷完了线代第三章');
    await settle(tester, frames: 2);
    await tester.tap(find.text('60'));
    await settle(tester, frames: 2);
    // 弹窗内容比屏幕高，底部「关联计划」需要先滚进可视区域才能点到
    final Finder planChip = find.text('数学一轮复习').last;
    await tester.ensureVisible(planChip);
    await settle(tester, frames: 4);
    await tester.tap(planChip);
    await settle(tester, frames: 2);
    await tester.tap(find.text('保存'));
    await settle(tester, frames: 12);

    expect(find.text('刷完了线代第三章'), findsWidgets);
    expect(find.text('1小时'), findsWidgets);
    expect(find.byType(JournalLogCard), findsOneWidget);
    expect(find.text('已记录'), findsOneWidget);

    // ---------- 写复盘 ----------
    await tapAt(tester, find.text('写复盘'));
    expect(find.text('学习复盘'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      '卡在特征值，明天先做 10 道题',
    );
    await settle(tester, frames: 2);
    await tester.tap(find.text('保存复盘'));
    await settle(tester, frames: 12);

    expect(find.text('已写'), findsOneWidget);
    expect(find.text('卡在特征值，明天先做 10 道题'), findsWidgets);

    // 关键：内容与复盘互不覆盖，都完整落在同一条记录里
    final List<JournalLog> logs = await repo.getLogs(JournalType.study);
    expect(logs.length, 1);
    expect(logs.single.content, '刷完了线代第三章');
    expect(logs.single.durationMinutes, 60);
    expect(logs.single.review, '卡在特征值，明天先做 10 道题');
    expect(logs.single.planId, plans.single.id);

    await disposeTree(tester);
  });

  testWidgets('左滑删除记录后可以撤销', (WidgetTester tester) async {
    await repo.saveLog(
      type: JournalType.study,
      date: DateTime.now(),
      content: '待删除的记录',
      durationMinutes: 45,
    );
    await openJournalPage(tester);

    expect(find.byType(JournalLogCard), findsOneWidget);
    expect(find.text('待删除的记录'), findsWidgets);

    final Finder card = find.byType(JournalLogCard).first;
    await tester.ensureVisible(card);
    await settle(tester, frames: 2);
    await tester.drag(card, const Offset(-140, 0));
    await settle(tester, frames: 12);

    expect(find.byType(JournalLogCard), findsNothing);
    expect(await repo.getLogs(JournalType.study), isEmpty);

    await tester.tap(find.text('撤销'));
    await settle(tester, frames: 12);

    expect(find.byType(JournalLogCard), findsOneWidget);
    final List<JournalLog> logs = await repo.getLogs(JournalType.study);
    expect(logs.length, 1);
    expect(logs.single.content, '待删除的记录');
    expect(logs.single.durationMinutes, 45);

    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    await disposeTree(tester);
  });

  testWidgets('学习 / 训练 互不干扰', (WidgetTester tester) async {
    await repo.addPlan(
      type: JournalType.study,
      title: '英语精读',
      content: '每天一篇',
    );
    await repo.saveLog(
      type: JournalType.training,
      date: DateTime.now(),
      content: '推日：卧推 4×8',
      durationMinutes: 70,
    );
    await openJournalPage(tester);

    // 默认在学习页：只有学习计划，没有训练记录
    expect(find.text('英语精读'), findsWidgets);
    expect(find.text('推日：卧推 4×8'), findsNothing);
    expect(find.text('还没有学习记录'), findsOneWidget);

    // 切到训练页
    await tapAt(tester, find.text('训练'));
    expect(find.text('推日：卧推 4×8'), findsWidgets);
    expect(find.text('英语精读'), findsNothing);
    expect(find.text('还没有训练计划'), findsOneWidget);
    expect(find.text('1小时10分'), findsWidgets);

    await disposeTree(tester);
  });
}
