import '../../core/utils/day_utils.dart';
import '../dao/ai_review_dao.dart';
import '../db/app_database.dart';
import '../models/enums.dart';

/// AI 复盘仓储。
///
/// 典型流程（阶段 7 会用到）：
/// 1. [startReview] 先落一条 pending 记录，拿到 id；
/// 2. 调用模型 API；
/// 3. 成功 → [complete]，失败 → [fail]。
class AiReviewRepository {
  AiReviewRepository(this._dao);

  final AiReviewDao _dao;

  Future<List<AiReview>> getAll() => _dao.getAll();

  Stream<List<AiReview>> watchAll() => _dao.watchAll();

  Future<AiReview?> latestOfDay(DateTime day) => _dao.getLatestOfDay(day);

  Stream<AiReview?> watchLatestOfDay(DateTime day) =>
      _dao.watchLatestOfDay(day);

  Future<AiReview?> getById(int id) => _dao.getById(id);

  Future<List<AiReview>> pendingList() => _dao.getByStatus(AiReviewStatus.pending);

  /// 开始一次复盘：先写入 pending。
  Future<int> startReview({
    required DateTime day,
    required String provider,
    required String model,
    String snapshotJson = '',
  }) =>
      _dao.insertPending(
        day: day,
        provider: provider,
        model: model,
        snapshotJson: snapshotJson,
      );

  Future<int> complete(int id, String content) =>
      _dao.markSuccess(id, content);

  Future<int> fail(int id, String message) => _dao.markFailed(id, message);

  Future<int> remove(int id) => _dao.deleteById(id);

  /// 撤销删除。
  Future<int> restore(AiReview review) => _dao.restore(review);

  /// 把「卡在 pending」的旧记录标成失败（例如上传中断、App 被杀）。
  Future<int> failStalePending({Duration olderThan = const Duration(minutes: 10)}) async {
    final List<AiReview> pendings = await _dao.getByStatus(AiReviewStatus.pending);
    final DateTime deadline = DateTime.now().subtract(olderThan);
    int count = 0;
    for (final AiReview review in pendings) {
      if (review.createdAt.isBefore(deadline)) {
        await _dao.markFailed(review.id, '任务中断（超时未返回）');
        count++;
      }
    }
    return count;
  }

  /// 某天是否已经生成过成功的复盘。
  Future<bool> hasSuccessfulReview(DateTime day) async {
    final AiReview? review = await _dao.getLatestOfDay(day);
    return review != null && review.status == AiReviewStatus.success;
  }

  /// 生成给模型用的上下文快照（占位：阶段 7 会塞入真实数据）。
  static String buildSnapshotJsonPlaceholder(DateTime day) =>
      '{"date":"${DayUtils.formatDate(day)}"}';
}
