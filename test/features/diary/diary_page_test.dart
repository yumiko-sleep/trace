import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/data/dao/diary_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/data/repositories/diary_repository.dart';
import 'package:trace/features/diary/presentation/widgets/diary_entry_card.dart';
import 'package:trace/features/home/presentation/widgets/section_tile.dart';

void main() {
  late AppDatabase db;
  late DiaryRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = DiaryRepository(DiaryDao(db));
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

  /// 打开 App 并进入「日记」页（主页第 3 个板块，位于第二行）。
  Future<void> openDiaryPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 测试视口只有 600px 高，第二行的入口在折叠线以下，必须先滚动到可见再点
    final Finder tile = find.byType(SectionTile).at(2);
    await tester.ensureVisible(tile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(tile);
    await settle(tester);
  }

  testWidgets('空状态 → 写一篇日记 → 出现在时间线', (WidgetTester tester) async {
    await openDiaryPage(tester);

    expect(find.text('还没有写过日记'), findsOneWidget);
    expect(find.byType(DiaryEntryCard), findsNothing);

    // 打开编辑页
    await tester.tap(find.text('写今天'));
    await settle(tester, frames: 12);
    expect(find.text('今天的心情'), findsOneWidget);
    expect(find.text('配图（可选）'), findsOneWidget);

    // 选心情 + 写正文
    await tester.tap(find.text('开心'));
    await settle(tester, frames: 2);
    await tester.enterText(
      find.byType(TextField).first,
      '今天把主页概览卡接上了真实数据，心情不错。',
    );
    await settle(tester, frames: 2);

    // 保存
    await tester.tap(find.text('保存'));
    await settle(tester, frames: 14);

    // 回到时间线
    expect(find.byType(DiaryEntryCard), findsOneWidget);
    expect(find.text('今天把主页概览卡接上了真实数据，心情不错。'), findsOneWidget);
    expect(find.text('😄 开心'), findsOneWidget);
    expect(find.text('今天'), findsWidgets);

    final List<DiaryEntry> entries = await repo.getAll();
    expect(entries.length, 1);
    expect(entries.single.mood, Mood.happy);

    await disposeTree(tester);
  });

  testWidgets('时间线展示已写日记，汇总同步更新', (WidgetTester tester) async {
    await repo.saveEntry(
      date: DateTime.now(),
      content: '第一天',
      mood: Mood.calm,
    );
    await repo.saveEntry(
      date: DateTime.now().subtract(const Duration(days: 1)),
      content: '昨天写的内容',
      mood: Mood.neutral,
    );
    await openDiaryPage(tester);

    expect(find.byType(DiaryEntryCard), findsNWidgets(2));
    expect(find.text('昨天写的内容'), findsOneWidget);
    expect(find.text('已记录 2 天'), findsOneWidget);
    expect(find.text('2 篇日记 · 0 张配图'), findsOneWidget);
    expect(find.text('今天已经写过了，随时可以补充'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('左滑删除后可以撤销', (WidgetTester tester) async {
    await repo.saveEntry(date: DateTime.now(), content: '待删除的日记');
    await openDiaryPage(tester);
    expect(find.text('待删除的日记'), findsOneWidget);

    await tester.drag(
      find.byType(DiaryEntryCard).first,
      const Offset(-140, 0),
    );
    await settle(tester, frames: 12);

    expect(find.text('待删除的日记'), findsNothing);
    expect(await repo.getAll(), isEmpty);

    await tester.tap(find.text('撤销'));
    await settle(tester, frames: 12);

    expect(find.text('待删除的日记'), findsOneWidget);
    expect((await repo.getAll()).length, 1);

    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    await disposeTree(tester);
  });
}
