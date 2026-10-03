import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/journal_repository.dart';
import '../domain/journal_stats.dart';

/// ============================================================
/// 「日志」板块的状态与操作。
/// ============================================================

/// 当前查看的日志类型（学习 / 训练）。
final StateProvider<JournalType> journalTypeProvider =
    StateProvider<JournalType>((Ref ref) => JournalType.study);

/// 当前类型下的计划（响应式）。
final AutoDisposeStreamProvider<List<JournalPlan>> journalPlansProvider =
    StreamProvider.autoDispose<List<JournalPlan>>((Ref ref) {
  final JournalType type = ref.watch(journalTypeProvider);
  return ref.watch(journalRepositoryProvider).watchPlans(type);
});

/// 当前类型下的全部记录，日期新的在前。
final AutoDisposeStreamProvider<List<JournalLog>> journalLogsProvider =
    StreamProvider.autoDispose<List<JournalLog>>((Ref ref) {
  final JournalType type = ref.watch(journalTypeProvider);
  return ref.watch(journalRepositoryProvider).watchLogs(type);
});

/// 今天的记录（没有则 null）。
final AutoDisposeProvider<JournalLog?> journalTodayLogProvider =
    Provider.autoDispose<JournalLog?>((Ref ref) {
  final List<JournalLog> logs =
      ref.watch(journalLogsProvider).valueOrNull ?? const <JournalLog>[];
  return findLogOfDay(logs, DateTime.now());
});

/// 当前类型的汇总统计。
final AutoDisposeProvider<JournalStats> journalStatsProvider =
    Provider.autoDispose<JournalStats>((Ref ref) {
  final List<JournalLog> logs =
      ref.watch(journalLogsProvider).valueOrNull ?? const <JournalLog>[];
  return computeJournalStats(logs);
});

/// planId → 计划标题（历史记录卡上展示「关联了哪个计划」）。
final AutoDisposeProvider<Map<int, String>> journalPlanTitlesProvider =
    Provider.autoDispose<Map<int, String>>((Ref ref) {
  final List<JournalPlan> plans =
      ref.watch(journalPlansProvider).valueOrNull ?? const <JournalPlan>[];
  return <int, String>{for (final JournalPlan p in plans) p.id: p.title};
});

/// 日志板块的写操作。
final Provider<JournalActions> journalActionsProvider =
    Provider<JournalActions>((Ref ref) => JournalActions(ref));

class JournalActions {
  JournalActions(this._ref);

  final Ref _ref;

  JournalRepository get _repo => _ref.read(journalRepositoryProvider);

  /// 保存某天的记录（同一天同类型只有一条，存在就更新）。
  ///
  /// 更新走 `updateLogContent`，只改内容 / 时长 / 关联计划，
  /// **不会**把已经写好的复盘清掉。
  Future<int> saveLog({
    required JournalType type,
    required DateTime date,
    String content = '',
    int? durationMinutes,
    int? planId,
  }) async {
    final List<JournalLog> existing = await _repo.getLogs(type, day: date);
    if (existing.isEmpty) {
      return _repo.saveLog(
        type: type,
        date: date,
        planId: planId,
        content: content,
        durationMinutes: durationMinutes,
      );
    }
    return _repo.updateLogContent(
      existing.first.id,
      content: content,
      durationMinutes: durationMinutes,
      planId: planId,
    );
  }

  /// 保存复盘段落（没有记录时先建一条只带复盘的记录）。
  Future<int> saveReview({
    required JournalType type,
    required DateTime date,
    required String review,
  }) async {
    final List<JournalLog> existing = await _repo.getLogs(type, day: date);
    if (existing.isEmpty) {
      return _repo.saveLog(type: type, date: date, review: review);
    }
    return _repo.saveReview(existing.first.id, review);
  }

  Future<int> removeLog(JournalLog log) => _repo.removeLog(log.id);

  /// 撤销删除。
  Future<int> restoreLog(JournalLog log) => _repo.restoreLog(log);
  Future<int> addPlan({
    required JournalType type,
    required String title,
    String content = '',
    int sortOrder = 0,
  }) =>
      _repo.addPlan(
        type: type,
        title: title,
        content: content,
        sortOrder: sortOrder,
      );

  Future<int> updatePlan(
    int id, {
    String? title,
    String? content,
    bool? isActive,
  }) =>
      _repo.updatePlan(id, title: title, content: content, isActive: isActive);

  Future<int> removePlan(JournalPlan plan) => _repo.removePlan(plan.id);

  /// 撤销删除计划。
  Future<int> restorePlan(JournalPlan plan) => _repo.restorePlan(plan);
}
