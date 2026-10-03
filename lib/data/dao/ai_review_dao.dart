import 'package:drift/drift.dart';

import '../../core/utils/day_utils.dart';
import '../db/app_database.dart';
import '../models/enums.dart';

/// AI 复盘 DAO。
class AiReviewDao {
  AiReviewDao(this._db);

  final AppDatabase _db;

  $AiReviewsTable get _table => _db.aiReviews;

  static List<OrderClauseGenerator<$AiReviewsTable>> get _defaultOrder =>
      <OrderClauseGenerator<$AiReviewsTable>>[
        ($AiReviewsTable t) =>
            OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ($AiReviewsTable t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ];

  Future<List<AiReview>> getAll() =>
      (_db.select(_table)..orderBy(_defaultOrder)).get();

  Stream<List<AiReview>> watchAll() =>
      (_db.select(_table)..orderBy(_defaultOrder)).watch();

  /// 某一天的最新一条复盘。
  Future<AiReview?> getLatestOfDay(DateTime day) => (_db.select(_table)
        ..where(
          ($AiReviewsTable t) => t.date.equals(DayUtils.dayStart(day)),
        )
        ..orderBy(_defaultOrder)
        ..limit(1))
      .getSingleOrNull();

  Stream<AiReview?> watchLatestOfDay(DateTime day) => (_db.select(_table)
        ..where(
          ($AiReviewsTable t) => t.date.equals(DayUtils.dayStart(day)),
        )
        ..orderBy(_defaultOrder)
        ..limit(1))
      .watchSingleOrNull();

  Future<List<AiReview>> getByStatus(AiReviewStatus status) =>
      (_db.select(_table)
            ..where(($AiReviewsTable t) => t.status.equalsValue(status))
            ..orderBy(_defaultOrder))
          .get();

  Future<AiReview?> getById(int id) =>
      (_db.select(_table)..where(($AiReviewsTable t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> insert(AiReviewsCompanion review) =>
      _db.into(_table).insert(review);

  /// 先落一条 pending 记录，拿到 id 后等模型返回再回填。
  Future<int> insertPending({
    required DateTime day,
    required String provider,
    required String model,
    String snapshotJson = '',
  }) =>
      insert(
        AiReviewsCompanion.insert(
          date: DayUtils.dayStart(day),
          status: AiReviewStatus.pending,
          provider: Value<String>(provider),
          model: Value<String>(model),
          snapshotJson: Value<String>(snapshotJson),
        ),
      );

  Future<bool> replace(AiReviewsCompanion review) =>
      _db.update(_table).replace(review);

  Future<int> updateFields(int id, AiReviewsCompanion fields) =>
      (_db.update(_table)..where(($AiReviewsTable t) => t.id.equals(id)))
          .write(fields);

  /// 回填成功结果。
  Future<int> markSuccess(int id, String content) => updateFields(
        id,
        AiReviewsCompanion(
          content: Value<String>(content),
          status: const Value<AiReviewStatus>(AiReviewStatus.success),
          errorMessage: const Value<String>(''),
        ),
      );

  /// 回填失败原因。
  Future<int> markFailed(int id, String message) => updateFields(
        id,
        AiReviewsCompanion(
          status: const Value<AiReviewStatus>(AiReviewStatus.failed),
          errorMessage: Value<String>(message),
        ),
      );

  Future<int> deleteById(int id) =>
      (_db.delete(_table)..where(($AiReviewsTable t) => t.id.equals(id))).go();

  Future<int> deleteAll() => _db.delete(_table).go();

  /// 恢复一条被删除的复盘（撤销用），保留原 id 与时间。
  Future<int> restore(AiReview review) => _db.into(_table).insert(
        AiReviewsCompanion(
          id: Value<int>(review.id),
          date: Value<DateTime>(review.date),
          provider: Value<String>(review.provider),
          model: Value<String>(review.model),
          content: Value<String>(review.content),
          status: Value<AiReviewStatus>(review.status),
          errorMessage: Value<String>(review.errorMessage),
          snapshotJson: Value<String>(review.snapshotJson),
          createdAt: Value<DateTime>(review.createdAt),
        ),
      );
}
