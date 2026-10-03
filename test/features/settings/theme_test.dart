import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/core/theme/app_motion.dart';
import 'package:trace/core/theme/app_scheme.dart';
import 'package:trace/data/dao/settings_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/data/repositories/settings_repository.dart';
import 'package:trace/features/home/presentation/widgets/section_tile.dart';
import 'package:trace/features/settings/providers/theme_providers.dart';

void main() {
  group('配色方案', () {
    test('两套方案 × 浅色/深色 = 4 种组合，颜色各不相同', () {
      expect(AppScheme.all.length, 4);
      expect(AppScheme.mintLight.isDark, isFalse);
      expect(AppScheme.mintDark.isDark, isTrue);

      expect(AppScheme.mintLight.mint, isNot(AppScheme.sakuraLight.mint));
      expect(AppScheme.mintDark.bgBottom, isNot(AppScheme.sakuraDark.bgBottom));
      expect(
        AppScheme.mintLight.header.colors,
        isNot(AppScheme.sakuraLight.header.colors),
      );

      expect(AppColorFamily.mint.of(Brightness.dark), AppScheme.mintDark);
      expect(AppColorFamily.sakura.of(Brightness.light), AppScheme.sakuraLight);

      expect(appColorFamilyFromId('sakura'), AppColorFamily.sakura);
      expect(
        appColorFamilyFromId('不存在'),
        AppColorFamily.mint,
        reason: '未知 id 回退到默认配色',
      );
    });

    test('浅色用深字、深色用亮字（对比度方向正确）', () {
      double lum(Color c) => c.computeLuminance();

      for (final AppScheme s in AppScheme.all) {
        expect(
          s.isDark ? lum(s.ink) : -lum(s.ink),
          greaterThan(s.isDark ? lum(s.bgBottom) : -lum(s.bgTop)),
          reason: '${s.label} 的文字与底色对比度方向不对',
        );
      }
    });

    test('每套方案都配齐了 9 条渐变与 id/label', () {
      for (final AppScheme s in AppScheme.all) {
        expect(s.primary.colors.length, greaterThanOrEqualTo(2));
        expect(s.header.colors.length, greaterThanOrEqualTo(2));
        expect(s.page.colors.length, 2);
        expect(s.disabled.colors.length, 2);
        expect(s.id, '${s.family.id}_${s.isDark ? 'dark' : 'light'}');
        expect(s.label, contains(s.isDark ? '深色' : '浅色'));
      }
    });
  });

  group('外观设置持久化', () {
    late AppDatabase db;
    late SettingsRepository repo;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.memory();
      repo = SettingsRepository(SettingsDao(db));
      container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('默认是跟随系统 + 薄荷绿蓝', () async {
      expect(await repo.themeModeId, 'system');
      expect(await repo.colorFamilyId, 'mint');

      await repo.setThemeModeId('dark');
      await repo.setColorFamilyId('sakura');
      expect(await repo.themeModeId, 'dark');
      expect(await repo.colorFamilyId, 'sakura');
    });

    test('provider 把存下来的 id 映射成 ThemeMode 与配色', () async {
      await repo.setThemeModeId('light');
      await repo.setColorFamilyId('sakura');

      final AppThemeSettings settings =
          await container.read(appThemeSettingsProvider.future);
      expect(settings.mode, ThemeMode.light);
      expect(settings.family, AppColorFamily.sakura);

      // 通过 actions 改配色：写库 + 让 provider 重新读取
      await container.read(themeActionsProvider).setFamily(AppColorFamily.mint);
      final AppThemeSettings again =
          await container.read(appThemeSettingsProvider.future);
      expect(again.family, AppColorFamily.mint);
      expect(again.mode, ThemeMode.light, reason: '亮度模式不受影响');
      expect(await repo.colorFamilyId, 'mint');
    });

    test('未知 id 不会崩，回退到默认', () async {
      await repo.setThemeModeId('乱填的');
      await repo.setColorFamilyId('乱填的');
      final AppThemeSettings settings =
          await container.read(appThemeSettingsProvider.future);
      expect(settings.mode, ThemeMode.system);
      expect(settings.family, AppColorFamily.mint);
    });
  });

  testWidgets('设置页切换配色与亮度：立即生效并落库', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 底部导航未选中项只有图标
    await tester.tap(find.byIcon(Icons.tune_rounded));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(
      find.textContaining('当前效果预览（薄荷绿蓝 · 浅色）'),
      findsOneWidget,
      reason: '默认方案',
    );

    // 换配色
    await tester.ensureVisible(find.text('樱花粉白'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('樱花粉白'));
    for (int i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.textContaining('当前效果预览（樱花粉白 · 浅色）'), findsOneWidget);
    expect(await SettingsRepository(SettingsDao(db)).colorFamilyId, 'sakura');

    // 换亮度
    await tester.ensureVisible(find.text('深色').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('深色').first);
    for (int i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(
      find.textContaining('当前效果预览（樱花粉白 · 深色）'),
      findsOneWidget,
    );
    expect(await SettingsRepository(SettingsDao(db)).themeModeId, 'dark');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('底部弹窗的入场/出场时长统一走 AppMotion', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 主页 → 目标 → 打开「新增目标」弹窗
    await tester.tap(find.byType(SectionTile).at(1));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.tap(find.text('新增目标'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 入场刚开始：弹窗还没滑到位
    final double midway = tester.getTopLeft(find.text('新建目标')).dy;

    await tester.pump(AppMotion.sheet + const Duration(milliseconds: 60));
    final double settled = tester.getTopLeft(find.text('新建目标')).dy;
    expect(settled, lessThan(midway), reason: '弹窗应该从下往上滑入');

    // 路由上挂的就是全局统一的那份时长
    final ModalRoute<Object?>? route =
        ModalRoute.of(tester.element(find.text('新建目标')));
    expect(route, isA<ModalBottomSheetRoute<void>>());
    final ModalBottomSheetRoute<void> sheet =
        route! as ModalBottomSheetRoute<void>;
    expect(sheet.sheetAnimationStyle?.duration, AppMotion.sheet);
    expect(sheet.sheetAnimationStyle?.reverseDuration, AppMotion.sheetOut);
    expect(AppMotion.sheetStyle.duration, AppMotion.sheet);
    expect(AppMotion.sheetStyle.reverseDuration, AppMotion.sheetOut);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
