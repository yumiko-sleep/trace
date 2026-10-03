import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/features/home/presentation/widgets/section_tile.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  /// 有界等待。
  ///
  /// 不用 `pumpAndSettle`：页面加载态里的 CircularProgressIndicator 是无限动画，
  /// pumpAndSettle 会一直等不到"没有动画"的状态（超时 10 分钟后报错）。
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// 收尾：drift 在取消「查询流」订阅时会排一个零延迟的定时器，
  /// 必须先卸载整棵树、再让定时器跑完，否则测试结束时会报
  /// "A Timer is still pending even after the widget tree was disposed"。
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpApp(WidgetTester tester) async {    await tester.pumpWidget(
      ProviderScope(
        // 用内存数据库替换真实数据库，测试才不会去碰 path_provider
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('主页渲染五个板块入口，并可进入「今日任务」', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('五大板块'), findsOneWidget);
    expect(find.byType(SectionTile), findsNWidgets(5));
    expect(find.text('目标'), findsOneWidget);
    expect(find.text('日记'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('日志'), findsOneWidget);

    // 进入第一个板块（今日任务，全屏页）
    await tester.tap(find.byType(SectionTile).first);
    await settle(tester);

    expect(find.text('今日完成'), findsOneWidget);
    expect(find.text('新增任务'), findsOneWidget);
    expect(find.text('今天还没有任务'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('底部导航可切换到设置页', (WidgetTester tester) async {
    await pumpApp(tester);

    // 未选中时导航项只显示图标，因此用图标定位
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await settle(tester);

    expect(find.text('AI 复盘'), findsWidgets);
    expect(find.text('服务商'), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('数据存储'), findsOneWidget);

    await disposeTree(tester);
  });
}
