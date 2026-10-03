import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/ai_review_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/repositories/ai_review_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late AiReviewRepository reviews;

  setUp(() {
    db = openTestDatabase();
    reviews = AiReviewRepository(AiReviewDao(db));
  });

  tearDown(() => db.close());

  group('AiReviewRepository', () {
    test('完整流程：pending → success', () async {
      final DateTime day = DateTime(2026, 10, 3, 22, 30);

      final int id = await reviews.startReview(
        day: day,
        provider: 'zhipu',
        model: 'glm-4v',
        snapshotJson: '{"tasks":3}',
      );

      AiReview review = (await reviews.getById(id))!;
      expect(review.status, AiReviewStatus.pending);
      expect(review.provider, 'zhipu');
      expect(review.model, 'glm-4v');
      expect(review.snapshotJson, '{"tasks":3}');
      expect(review.date, DateTime(2026, 10, 3), reason: '日期归一化到当天 00:00');

      await reviews.complete(id, '今天完成了 3 件事，明天把手机放远一点。');
      review = (await reviews.getById(id))!;
      expect(review.status, AiReviewStatus.success);
      expect(review.content, '今天完成了 3 件事，明天把手机放远一点。');
      expect(review.errorMessage, isEmpty);

      expect(await reviews.hasSuccessfulReview(day), isTrue);
    });

    test('失败流程会记录错误信息', () async {
      final int id = await reviews.startReview(
        day: DateTime(2026, 10, 3),
        provider: 'zhipu',
        model: 'glm-4v',
      );

      await reviews.fail(id, 'HTTP 401：API Key 无效');
      final AiReview review = (await reviews.getById(id))!;
      expect(review.status, AiReviewStatus.failed);
      expect(review.errorMessage, contains('401'));
      expect(await reviews.hasSuccessfulReview(DateTime(2026, 10, 3)), isFalse);
    });

    test('latestOfDay 取当天最新一条', () async {
      final DateTime day = DateTime(2026, 10, 3);
      await reviews.startReview(day: day, provider: 'zhipu', model: 'glm-4v');
      final int second =
          await reviews.startReview(day: day, provider: 'gemini', model: 'flash');

      final AiReview latest = (await reviews.latestOfDay(day))!;
      expect(latest.id, second);
      expect(latest.provider, 'gemini');
    });

    test('failStalePending 把卡住的旧任务标记为失败', () async {
      final int stuck =
          await reviews.startReview(day: DateTime.now(), provider: 'a', model: 'b');
      final int fresh =
          await reviews.startReview(day: DateTime.now(), provider: 'a', model: 'b');

      // 只有"很久以前"的记录会被判定为超时
      final int count =
          await reviews.failStalePending(olderThan: const Duration(milliseconds: 1));
      expect(count, 2);

      expect((await reviews.getById(stuck))!.status, AiReviewStatus.failed);
      expect((await reviews.getById(fresh))!.status, AiReviewStatus.failed);
      expect(await reviews.pendingList(), isEmpty);
    });

    test('删除复盘记录', () async {
      final int id = await reviews.startReview(
        day: DateTime(2026, 10, 3),
        provider: 'zhipu',
        model: 'glm-4v',
      );
      expect(await reviews.remove(id), 1);
      expect(await reviews.getById(id), isNull);
    });

    test('watchLatestOfDay 是响应式流', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final Stream<AiReview?> stream = reviews.watchLatestOfDay(day);

      final Future<void> expectation = expectLater(
        stream,
        emitsThrough(
          predicate<AiReview?>(
            (AiReview? r) => r != null && r.content == '生成完毕',
          ),
        ),
      );

      final int id = await reviews.startReview(
        day: day,
        provider: 'zhipu',
        model: 'glm-4v',
      );
      await reviews.complete(id, '生成完毕');
      await expectation;
    });
  });
}
