import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../dao/diary_dao.dart';
import '../db/app_database.dart';
import '../models/enums.dart';

/// 日记仓储：负责「一篇日记 + 它的多张图片」的整体读写。
class DiaryRepository {
  DiaryRepository(this._dao);

  final DiaryDao _dao;

  // ---------------- 读 ----------------

  Future<List<DiaryEntry>> getAll() => _dao.getAll();

  Stream<List<DiaryEntry>> watchAll() => _dao.watchAll();

  Future<DiaryEntry?> getByDay(DateTime day) => _dao.getByDay(day);

  Stream<DiaryEntry?> watchByDay(DateTime day) => _dao.watchByDay(day);

  Future<DiaryEntry?> getById(int id) => _dao.getById(id);

  Future<List<DiaryImage>> getImages(int entryId) => _dao.getImages(entryId);

  Stream<List<DiaryImage>> watchImages(int entryId) =>
      _dao.watchImages(entryId);

  Future<Map<int, List<DiaryImage>>> getImagesForEntries(List<int> entryIds) =>
      _dao.getImagesForEntries(entryIds);

  /// 最近 n 天写日记的天数（用于连续记录统计）。
  Future<int> countDaysWithEntry(int days) async {
    final List<DiaryEntry> entries = await _dao.getBetween(
      DayUtils.dayStart(DateTime.now()).subtract(Duration(days: days - 1)),
      DateTime.now(),
    );
    return entries
        .map((DiaryEntry e) => DayUtils.formatDate(e.date))
        .toSet()
        .length;
  }

  // ---------------- 写 ----------------

  /// 新建一篇日记（可同时带多张图片）。同一个事务，要么全成功要么全失败。
  Future<int> createEntry({
    required DateTime date,
    String content = '',
    Mood? mood,
    List<String> imagePaths = const <String>[],
  }) {
    return _dao.saveEntryWithImages(
      DiaryEntriesCompanion.insert(
        date: DayUtils.dayStart(date),
        content: Value<String>(content),
        mood: Value<Mood?>(mood),
      ),
      <DiaryImagesCompanion>[
        for (int i = 0; i < imagePaths.length; i++)
          DiaryImagesCompanion.insert(
            entryId: 0,
            path: imagePaths[i],
            sortOrder: Value<int>(i),
          ),
      ],
    );
  }

  /// 更新正文 / 心情。
  Future<int> updateEntry(
    int id, {
    String? content,
    Mood? mood,
    bool clearMood = false,
  }) {
    return _dao.updateEntry(
      id,
      DiaryEntriesCompanion(
        content: content == null ? const Value.absent() : Value<String>(content),
        mood: clearMood
            ? const Value<Mood?>(null)
            : (mood == null ? const Value.absent() : Value<Mood?>(mood)),
      ),
    );
  }

  /// 「保存今天的日记」：有就更新，没有就新建（带图）。
  Future<int> saveDay({
    required DateTime date,
    required String content,
    Mood? mood,
    List<String> imagePaths = const <String>[],
  }) async {
    final DiaryEntry? existing = await _dao.getByDay(date);
    if (existing == null) {
      return createEntry(
        date: date,
        content: content,
        mood: mood,
        imagePaths: imagePaths,
      );
    }
    await updateEntry(existing.id, content: content, mood: mood, clearMood: mood == null);
    if (imagePaths.isNotEmpty) {
      await _dao.deleteImagesOfEntry(existing.id);
      await _dao.insertImages(<DiaryImagesCompanion>[
        for (int i = 0; i < imagePaths.length; i++)
          DiaryImagesCompanion.insert(
            entryId: existing.id,
            path: imagePaths[i],
            sortOrder: Value<int>(i),
          ),
      ]);
    }
    return existing.id;
  }

  Future<int> addImage(int entryId, String path, {int sortOrder = 0, String caption = ''}) =>
      _dao.insertImage(
        DiaryImagesCompanion.insert(
          entryId: entryId,
          path: path,
          caption: Value<String>(caption),
          sortOrder: Value<int>(sortOrder),
        ),
      );

  Future<int> removeImage(int imageId) => _dao.deleteImage(imageId);

  Future<int> removeEntry(int entryId) => _dao.deleteEntry(entryId);

  // ---------------- 编辑页 / 时间线专用 ----------------

  /// 保存某一天的日记（正文 + 心情 + 图片列表整体替换），同一事务。
  Future<int> saveEntry({
    required DateTime date,
    required String content,
    Mood? mood,
    List<String> imagePaths = const <String>[],
  }) {
    return _dao.upsertEntry(
      date: date,
      content: content,
      mood: mood,
      imagePaths: imagePaths,
    );
  }

  /// entryId → 图片列表（响应式，一次查询拿全，供时间线用）。
  Stream<Map<int, List<DiaryImage>>> watchImagesByEntry() =>
      _dao.watchAllImages().map(_groupByEntry);

  /// 恢复一篇被删除的日记（连同图片记录）。
  Future<void> restoreEntry(DiaryEntry entry, List<DiaryImage> images) =>
      _dao.restoreEntry(entry, images);

  static Map<int, List<DiaryImage>> _groupByEntry(List<DiaryImage> images) {
    final Map<int, List<DiaryImage>> map = <int, List<DiaryImage>>{};
    for (final DiaryImage image in images) {
      map.putIfAbsent(image.entryId, () => <DiaryImage>[]).add(image);
    }
    for (final List<DiaryImage> list in map.values) {
      list.sort((DiaryImage a, DiaryImage b) =>
          a.sortOrder.compareTo(b.sortOrder));
    }
    return map;
  }
}
