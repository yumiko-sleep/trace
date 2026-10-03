import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../db/app_database.dart';
import '../models/enums.dart';

/// 日记 DAO：同时管 `diary_entries` 与 `diary_images` 两张表。
class DiaryDao {
  DiaryDao(this._db);

  final AppDatabase _db;

  $DiaryEntriesTable get _entries => _db.diaryEntries;
  $DiaryImagesTable get _images => _db.diaryImages;

  static List<OrderClauseGenerator<$DiaryEntriesTable>> get _entryOrder =>
      <OrderClauseGenerator<$DiaryEntriesTable>>[
        ($DiaryEntriesTable t) =>
            OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ];

  static List<OrderClauseGenerator<$DiaryImagesTable>> get _imageOrder =>
      <OrderClauseGenerator<$DiaryImagesTable>>[
        ($DiaryImagesTable t) => OrderingTerm(expression: t.sortOrder),
      ];

  // ---------------- 日记 ----------------

  Future<List<DiaryEntry>> getAll() =>
      (_db.select(_entries)..orderBy(_entryOrder)).get();

  Stream<List<DiaryEntry>> watchAll() =>
      (_db.select(_entries)..orderBy(_entryOrder)).watch();

  /// 某一天的日记（正常情况下 0 或 1 条）。
  Future<DiaryEntry?> getByDay(DateTime day) => (_db.select(_entries)
        ..where(
          ($DiaryEntriesTable t) => t.date.equals(DayUtils.dayStart(day)),
        ))
      .getSingleOrNull();

  Stream<DiaryEntry?> watchByDay(DateTime day) => (_db.select(_entries)
        ..where(
          ($DiaryEntriesTable t) => t.date.equals(DayUtils.dayStart(day)),
        ))
      .watchSingleOrNull();

  Future<DiaryEntry?> getById(int id) =>
      (_db.select(_entries)..where(($DiaryEntriesTable t) => t.id.equals(id)))
          .getSingleOrNull();

  /// 按时间范围取日记（用于列表 / 日历）。
  Future<List<DiaryEntry>> getBetween(DateTime from, DateTime to) =>
      (_db.select(_entries)
            ..where(
              ($DiaryEntriesTable t) => t.date.isBetweenValues(
                DayUtils.dayStart(from),
                DayUtils.dayEnd(to),
              ),
            )
            ..orderBy(_entryOrder))
          .get();

  Future<List<DiaryEntry>> getByMood(Mood mood) => (_db.select(_entries)
        ..where(($DiaryEntriesTable t) => t.mood.equalsValue(mood)))
      .get();

  Future<int> countAll() async => (await getAll()).length;

  Future<int> insertEntry(DiaryEntriesCompanion entry) =>
      _db.into(_entries).insert(entry);

  Future<bool> replaceEntry(DiaryEntriesCompanion entry) =>
      _db.update(_entries).replace(entry);

  Future<int> updateEntry(int id, DiaryEntriesCompanion fields) =>
      (_db.update(_entries)
            ..where(($DiaryEntriesTable t) => t.id.equals(id)))
          .write(fields.copyWith(updatedAt: Value<DateTime>(DateTime.now())));

  Future<int> deleteEntry(int id) =>
      (_db.delete(_entries)..where(($DiaryEntriesTable t) => t.id.equals(id)))
          .go();

  Future<int> deleteAllEntries() => _db.delete(_entries).go();

  // ---------------- 图片 ----------------

  Future<List<DiaryImage>> getImages(int entryId) => (_db.select(_images)
        ..where(($DiaryImagesTable t) => t.entryId.equals(entryId))
        ..orderBy(_imageOrder))
      .get();

  Stream<List<DiaryImage>> watchImages(int entryId) => (_db.select(_images)
        ..where(($DiaryImagesTable t) => t.entryId.equals(entryId))
        ..orderBy(_imageOrder))
      .watch();

  /// 一次性取多条日记的图片，按 entryId 分组（列表页避免 N+1 查询）。
  Future<Map<int, List<DiaryImage>>> getImagesForEntries(
    List<int> entryIds,
  ) async {
    if (entryIds.isEmpty) return <int, List<DiaryImage>>{};
    final List<DiaryImage> rows = await (_db.select(_images)
          ..where(($DiaryImagesTable t) => t.entryId.isIn(entryIds))
          ..orderBy(_imageOrder))
        .get();
    final Map<int, List<DiaryImage>> grouped = <int, List<DiaryImage>>{};
    for (final DiaryImage image in rows) {
      grouped.putIfAbsent(image.entryId, () => <DiaryImage>[]).add(image);
    }
    return grouped;
  }

  Future<int> insertImage(DiaryImagesCompanion image) =>
      _db.into(_images).insert(image);

  Future<void> insertImages(List<DiaryImagesCompanion> images) =>
      _db.batch((Batch b) => b.insertAll(_images, images));

  Future<int> deleteImage(int id) =>
      (_db.delete(_images)..where(($DiaryImagesTable t) => t.id.equals(id)))
          .go();

  Future<int> deleteImagesOfEntry(int entryId) => (_db.delete(_images)
        ..where(($DiaryImagesTable t) => t.entryId.equals(entryId)))
      .go();

  /// 保存「一条日记 + 它的图片」，放在同一个事务里，要么全成功要么全失败。
  Future<int> saveEntryWithImages(
    DiaryEntriesCompanion entry,
    List<DiaryImagesCompanion> images,
  ) {
    return _db.transaction(() async {
      final int entryId = await _db.into(_entries).insert(entry);
      if (images.isNotEmpty) {
        await _db.batch(
          (Batch b) => b.insertAll(
            _images,
            images
                .map(
                  (DiaryImagesCompanion i) =>
                      i.copyWith(entryId: Value<int>(entryId)),
                )
                .toList(),
          ),
        );
      }
      return entryId;
    });
  }

  // ---------------- 编辑页专用 ----------------

  /// 「保存某一天的日记」：没有就新建，有就把正文 / 心情 / 图片列表整体替换。
  ///
  /// 整个过程包在一个事务里，中途失败不会留下「日记存了但图丢了」的脏数据。
  Future<int> upsertEntry({
    required DateTime date,
    required String content,
    required Mood? mood,
    required List<String> imagePaths,
  }) {
    return _db.transaction<int>(() async {
      final DiaryEntry? existing = await getByDay(date);
      final int entryId;
      if (existing == null) {
        entryId = await _db.into(_entries).insert(
              DiaryEntriesCompanion.insert(
                date: DayUtils.dayStart(date),
                content: Value<String>(content),
                mood: Value<Mood?>(mood),
              ),
            );
      } else {
        entryId = existing.id;
        await updateEntry(
          entryId,
          DiaryEntriesCompanion(
            content: Value<String>(content),
            mood: Value<Mood?>(mood),
          ),
        );
      }

      await deleteImagesOfEntry(entryId);
      if (imagePaths.isNotEmpty) {
        await insertImages(<DiaryImagesCompanion>[
          for (int i = 0; i < imagePaths.length; i++)
            DiaryImagesCompanion.insert(
              entryId: entryId,
              path: imagePaths[i],
              sortOrder: Value<int>(i),
            ),
        ]);
      }
      return entryId;
    });
  }

  /// 全部图片（时间线一次性拿全所有缩略图，避免每个条目查一次）。
  Stream<List<DiaryImage>> watchAllImages() => _db.select(_images).watch();

  Future<List<DiaryImage>> getAllImages() => _db.select(_images).get();

  /// 恢复一篇被删除的日记（连同它的图片记录），保留原 id 与创建时间。
  Future<void> restoreEntry(DiaryEntry entry, List<DiaryImage> images) {
    return _db.transaction(() async {
      await _db.into(_entries).insert(
            DiaryEntriesCompanion(
              id: Value<int>(entry.id),
              date: Value<DateTime>(entry.date),
              content: Value<String>(entry.content),
              mood: Value<Mood?>(entry.mood),
              createdAt: Value<DateTime>(entry.createdAt),
              updatedAt: Value<DateTime>(entry.updatedAt),
            ),
          );
      if (images.isNotEmpty) {
        await _db.batch((Batch b) {
          b.insertAll(_images, <DiaryImagesCompanion>[
            for (final DiaryImage image in images)
              DiaryImagesCompanion(
                id: Value<int>(image.id),
                entryId: Value<int>(entry.id),
                path: Value<String>(image.path),
                caption: Value<String>(image.caption),
                sortOrder: Value<int>(image.sortOrder),
                createdAt: Value<DateTime>(image.createdAt),
              ),
          ]);
        });
      }
    });
  }
}
