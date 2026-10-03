import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/settings_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/repositories/settings_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = openTestDatabase();
    settings = SettingsRepository(SettingsDao(db));
  });

  tearDown(() => db.close());

  group('SettingsRepository', () {
    test('字符串读写与覆盖', () async {
      expect(await settings.getString('theme'), isNull);
      await settings.setString('theme', 'light');
      expect(await settings.getString('theme'), 'light');
      await settings.setString('theme', 'dark');
      expect(await settings.getString('theme'), 'dark');
      expect((await settings.getAll()).length, 1, reason: '同一个 key 只应有一行');
    });

    test('布尔值：支持 true/false 与 1/0 两种写法', () async {
      expect(await settings.getBool('flag'), isFalse);
      expect(await settings.getBool('flag', defaultValue: true), isTrue);

      await settings.setBool('flag', true);
      expect(await settings.getBool('flag'), isTrue);

      await settings.setString('flag', '0');
      expect(await settings.getBool('flag'), isFalse);
    });

    test('整数读写', () async {
      expect(await settings.getInt('hour'), isNull);
      await settings.setInt('hour', 22);
      expect(await settings.getInt('hour'), 22);
    });

    test('AI 供应商与模型有默认值', () async {
      expect(await settings.aiProvider, 'deepseek');
      expect(await settings.aiModel, 'deepseek-v4-pro');
      expect(await settings.aiBaseUrl, '');

      await settings.setAiProvider('gemini');
      await settings.setAiModel('gemini-2.5-flash');
      await settings.setAiBaseUrl('https://example.com/v1');
      expect(await settings.aiProvider, 'gemini');
      expect(await settings.aiModel, 'gemini-2.5-flash');
      expect(await settings.aiBaseUrl, 'https://example.com/v1');
    });

    test('自动复盘开关', () async {
      expect(await settings.autoReviewEnabled, isFalse);
      await settings.setAutoReviewEnabled(true);
      expect(await settings.autoReviewEnabled, isTrue);
    });

    test('删除与清空', () async {
      await settings.setString('a', '1');
      await settings.setString('b', '2');
      expect(await settings.remove('a'), 1);
      expect(await settings.getString('a'), isNull);

      await settings.clear();
      expect((await settings.getAll()), isEmpty);
    });

    test('markFirstLaunchIfNeeded 只写一次', () async {
      await settings.markFirstLaunchIfNeeded();
      final String? first = await settings.getString(SettingsKeys.firstLaunchAt);
      expect(first, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await settings.markFirstLaunchIfNeeded();
      expect(
        await settings.getString(SettingsKeys.firstLaunchAt),
        first,
        reason: '第二次调用不应覆盖首次时间',
      );
    });
  });
}
