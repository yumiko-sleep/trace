import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/diary_repository.dart';

/// ============================================================
/// 「日记」板块的状态与操作。
/// ============================================================

/// 全部日记，新的在前（时间线）。
final AutoDisposeStreamProvider<List<DiaryEntry>> diaryEntriesProvider =
    StreamProvider.autoDispose<List<DiaryEntry>>((Ref ref) {
  return ref.watch(diaryRepositoryProvider).watchAll();
});

/// entryId → 该篇日记的图片列表（一次查询拿全，响应式）。
final AutoDisposeStreamProvider<Map<int, List<DiaryImage>>>
    diaryImagesProvider =
    StreamProvider.autoDispose<Map<int, List<DiaryImage>>>((Ref ref) {
  return ref.watch(diaryRepositoryProvider).watchImagesByEntry();
});

/// 时间线的汇总统计。
final Provider<DiaryStats> diaryStatsProvider = Provider<DiaryStats>((Ref ref) {
  final List<DiaryEntry> entries =
      ref.watch(diaryEntriesProvider).valueOrNull ?? const <DiaryEntry>[];
  final Map<int, List<DiaryImage>> images =
      ref.watch(diaryImagesProvider).valueOrNull ??
          const <int, List<DiaryImage>>{};

  return DiaryStats(
    days: entries.map((DiaryEntry e) => e.date).toSet().length,
    entries: entries.length,
    images: images.values.fold<int>(
      0,
      (int acc, List<DiaryImage> list) => acc + list.length,
    ),
  );
});

/// 日记写操作。
final Provider<DiaryActions> diaryActionsProvider =
    Provider<DiaryActions>((Ref ref) => DiaryActions(ref));

class DiaryActions {
  DiaryActions(this._ref);

  final Ref _ref;

  DiaryRepository get _repo => _ref.read(diaryRepositoryProvider);

  /// 保存某一天的日记（正文 + 心情 + 图片列表整体替换）。
  Future<int> save({
    required DateTime date,
    required String content,
    Mood? mood,
    List<String> imagePaths = const <String>[],
  }) {
    return _repo.saveEntry(
      date: date,
      content: content,
      mood: mood,
      imagePaths: imagePaths,
    );
  }

  /// 删除一篇日记。
  ///
  /// 只删数据库记录：图片文件刻意保留，这样「撤销」能把整篇日记连图一起恢复。
  /// 孤儿图片文件的清理放到阶段 8（数据维护）。
  Future<int> remove(DiaryEntry entry) => _repo.removeEntry(entry.id);

  /// 按 id 删除（编辑页把内容清空时用）。
  Future<int> removeById(int entryId) => _repo.removeEntry(entryId);

  /// 恢复一篇被删除的日记（撤销用）。
  Future<void> restore(DiaryEntry entry, List<DiaryImage> images) async {
    await _repo.restoreEntry(entry, images);
  }
}
