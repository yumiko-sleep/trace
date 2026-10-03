import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/diary_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/repositories/diary_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiaryRepository diary;

  setUp(() {
    db = openTestDatabase();
    diary = DiaryRepository(DiaryDao(db));
  });

  tearDown(() => db.close());

  group('DiaryRepository', () {
    test('新建日记：文字 + 心情 + 多张图片（同一事务）', () async {
      final int id = await diary.createEntry(
        date: DateTime(2026, 10, 3, 22, 30),
        content: '今天把数据层写完了。',
        mood: Mood.happy,
        imagePaths: <String>['/img/a.jpg', '/img/b.jpg', '/img/c.jpg'],
      );

      final DiaryEntry entry = (await diary.getById(id))!;
      expect(entry.content, '今天把数据层写完了。');
      expect(entry.mood, Mood.happy);
      expect(entry.date, DateTime(2026, 10, 3), reason: '日期应归一到当天 00:00');

      final List<DiaryImage> images = await diary.getImages(id);
      expect(images.length, 3);
      expect(
        images.map((DiaryImage i) => i.path),
        <String>['/img/a.jpg', '/img/b.jpg', '/img/c.jpg'],
        reason: '顺序按 sortOrder 保持传入顺序',
      );
    });

    test('按日期查询 / 更新内容与心情', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final int id = await diary.createEntry(date: day, content: '初稿');

      expect((await diary.getByDay(day))!.id, id);
      expect((await diary.getByDay(DateTime(2026, 10, 4))), isNull);

      await diary.updateEntry(id, content: '改过的正文', mood: Mood.calm);
      final DiaryEntry entry = (await diary.getById(id))!;
      expect(entry.content, '改过的正文');
      expect(entry.mood, Mood.calm);

      await diary.updateEntry(id, clearMood: true);
      expect((await diary.getById(id))!.mood, isNull);
    });

    test('saveDay：当天已有日记就更新，没有就新建', () async {
      final DateTime day = DateTime(2026, 10, 3);

      final int first = await diary.saveDay(
        date: day,
        content: '第一次',
        mood: Mood.neutral,
      );
      final int second = await diary.saveDay(
        date: day,
        content: '第二次（覆盖）',
        mood: Mood.happy,
      );
      expect(second, first, reason: '应该是同一条记录被更新');
      expect((await diary.getAll()).length, 1);
      expect((await diary.getById(first))!.content, '第二次（覆盖）');
    });

    test('saveDay 传入新图片时会替换旧图片', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final int id = await diary.saveDay(
        date: day,
        content: 'x',
        imagePaths: <String>['/old1.jpg', '/old2.jpg'],
      );
      expect((await diary.getImages(id)).length, 2);

      await diary.saveDay(
        date: day,
        content: 'x',
        imagePaths: <String>['/new1.jpg'],
      );
      final List<DiaryImage> images = await diary.getImages(id);
      expect(images.length, 1);
      expect(images.single.path, '/new1.jpg');
    });

    test('删除日记会级联删掉它的图片', () async {
      final int id = await diary.createEntry(
        date: DateTime(2026, 10, 3),
        content: '带图的日记',
        imagePaths: <String>['/a.jpg', '/b.jpg'],
      );
      expect((await diary.getImages(id)).length, 2);

      await diary.removeEntry(id);
      expect(await diary.getById(id), isNull);
      expect(await diary.getImages(id), isEmpty, reason: '外键 cascade 应该自动清理');
    });

    test('单独增删图片', () async {
      final int id = await diary.createEntry(date: DateTime(2026, 10, 3));
      final int imgId = await diary.addImage(id, '/single.jpg', caption: '晚饭');
      final List<DiaryImage> images = await diary.getImages(id);
      expect(images.length, 1);
      expect(images.single.caption, '晚饭');

      await diary.removeImage(imgId);
      expect(await diary.getImages(id), isEmpty);
    });

    test('批量取多条日记的图片（避免 N+1 查询）', () async {
      final int a = await diary.createEntry(
        date: DateTime(2026, 10, 1),
        imagePaths: <String>['/a1.jpg'],
      );
      final int b = await diary.createEntry(
        date: DateTime(2026, 10, 2),
        imagePaths: <String>['/b1.jpg', '/b2.jpg'],
      );

      final Map<int, List<DiaryImage>> grouped =
          await diary.getImagesForEntries(<int>[a, b]);
      expect(grouped[a]!.length, 1);
      expect(grouped[b]!.length, 2);
      expect(await diary.getImagesForEntries(<int>[]), isEmpty);
    });

    test('countDaysWithEntry 统计最近记录天数', () async {
      await diary.createEntry(date: DateTime.now());
      await diary.createEntry(
        date: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(await diary.countDaysWithEntry(7), 2);
    });
  });
}
