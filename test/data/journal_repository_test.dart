import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/journal_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/repositories/journal_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late JournalRepository journal;

  setUp(() {
    db = openTestDatabase();
    journal = JournalRepository(JournalDao(db));
  });

  tearDown(() => db.close());

  group('JournalRepository', () {
    test('学习计划与训练计划互不干扰', () async {
      await journal.addPlan(type: JournalType.study, title: '英语：新概念 2');
      await journal.addPlan(type: JournalType.study, title: '算法：每天 1 题');
      await journal.addPlan(type: JournalType.training, title: '推拉腿');

      expect((await journal.getPlans(JournalType.study)).length, 2);
      expect((await journal.getPlans(JournalType.training)).length, 1);
      expect(
        (await journal.getPlans(JournalType.training)).single.title,
        '推拉腿',
      );
    });

    test('计划默认启用，可以编辑标题与正文', () async {
      final int id = await journal.addPlan(
        type: JournalType.study,
        title: '旧标题',
      );
      expect((await journal.getPlanById(id))!.isActive, isTrue);

      await journal.updatePlan(id, title: '新标题', content: '第一章…');
      final JournalPlan plan = (await journal.getPlanById(id))!;
      expect(plan.title, '新标题');
      expect(plan.content, '第一章…');

      await journal.updatePlan(id, isActive: false);
      expect((await journal.getPlans(JournalType.study)).length, 1);
      expect(
        (await journal.getPlans(JournalType.study, onlyActive: true)).length,
        0,
      );
    });

    test('每天每类型只有一条记录（saveLog 是 upsert 语义）', () async {
      final DateTime day = DateTime(2026, 10, 3, 21);

      final int first = await journal.saveLog(
        type: JournalType.study,
        date: day,
        content: '背了 50 个单词',
        durationMinutes: 40,
      );
      final int second = await journal.saveLog(
        type: JournalType.study,
        date: day,
        content: '背了 80 个单词',
        durationMinutes: 60,
      );

      expect(second, first);
      final List<JournalLog> logs = await journal.getLogsOfDay(day);
      expect(logs.length, 1);
      expect(logs.single.content, '背了 80 个单词');
      expect(logs.single.durationMinutes, 60);
    });

    test('学习和训练同一天可以各有一条', () async {
      final DateTime day = DateTime(2026, 10, 3);
      await journal.saveLog(type: JournalType.study, date: day, content: '学习');
      await journal.saveLog(type: JournalType.training, date: day, content: '训练');

      expect((await journal.getLogsOfDay(day)).length, 2);
      expect((await journal.getLogs(JournalType.study, day: day)).length, 1);
    });

    test('记录可以关联计划；计划删除后关联置空、记录保留', () async {
      final int planId = await journal.addPlan(
        type: JournalType.training,
        title: '推拉腿',
      );
      final DateTime day = DateTime(2026, 10, 3);
      final int logId = await journal.saveLog(
        type: JournalType.training,
        date: day,
        planId: planId,
        content: '推：卧推 5x5',
        durationMinutes: 70,
      );

      expect((await journal.getLogById(logId))!.planId, planId);

      await journal.removePlan(planId);
      final JournalLog log = (await journal.getLogById(logId))!;
      expect(log.planId, isNull);
      expect(log.content, '推：卧推 5x5');
    });

    test('复盘可以单独保存', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final int logId = await journal.saveLog(
        type: JournalType.study,
        date: day,
        content: '学习内容',
      );

      await journal.saveReview(logId, '今天效率不错，明天把时间挪到早上。');
      expect(
        (await journal.getLogById(logId))!.review,
        '今天效率不错，明天把时间挪到早上。',
      );
    });

    test('totalMinutes 汇总最近几天的学习 + 训练时长', () async {
      final DateTime today = DateTime.now();
      await journal.saveLog(
        type: JournalType.study,
        date: today,
        durationMinutes: 60,
      );
      await journal.saveLog(
        type: JournalType.training,
        date: today,
        durationMinutes: 45,
      );
      await journal.saveLog(
        type: JournalType.study,
        date: today.subtract(const Duration(days: 30)),
        durationMinutes: 999,
      );

      expect(await journal.totalMinutes(7), 105);
    });

    test('删除记录', () async {
      final int id = await journal.saveLog(
        type: JournalType.study,
        date: DateTime(2026, 10, 3),
      );
      expect(await journal.removeLog(id), 1);
      expect(await journal.getLogById(id), isNull);
    });

    test('updateLogContent 改内容 / 时长 / 关联计划，但不动复盘', () async {
      final int planId =
          await journal.addPlan(type: JournalType.study, title: '数学一轮');
      final int id = await journal.saveLog(
        type: JournalType.study,
        date: DateTime(2026, 10, 3),
        content: '原本的内容',
        durationMinutes: 30,
        review: '原本的复盘，不能被顺手删掉',
      );

      await journal.updateLogContent(
        id,
        content: '改过的内容',
        durationMinutes: 90,
        planId: planId,
      );

      final JournalLog log = (await journal.getLogById(id))!;
      expect(log.content, '改过的内容');
      expect(log.durationMinutes, 90);
      expect(log.planId, planId);
      expect(log.review, '原本的复盘，不能被顺手删掉');
    });

    test('updateLogContent 可以把时长与关联计划清空', () async {
      final int planId =
          await journal.addPlan(type: JournalType.study, title: '数学一轮');
      final int id = await journal.saveLog(
        type: JournalType.study,
        date: DateTime(2026, 10, 3),
        content: '内容',
        durationMinutes: 30,
        planId: planId,
      );

      await journal.updateLogContent(id, content: '内容');

      final JournalLog log = (await journal.getLogById(id))!;
      expect(log.durationMinutes, isNull);
      expect(log.planId, isNull);
    });

    test('saveReview 只动复盘段落', () async {
      final int id = await journal.saveLog(
        type: JournalType.study,
        date: DateTime(2026, 10, 3),
        content: '内容',
        durationMinutes: 45,
      );

      await journal.saveReview(id, '今天的复盘');

      final JournalLog log = (await journal.getLogById(id))!;
      expect(log.review, '今天的复盘');
      expect(log.content, '内容');
      expect(log.durationMinutes, 45);
    });

    test('restoreLog 恢复删除的记录并保留原 id', () async {
      final int id = await journal.saveLog(
        type: JournalType.training,
        date: DateTime(2026, 10, 3),
        content: '推日：卧推 4×8',
        durationMinutes: 70,
        review: '下次加 2.5kg',
      );
      final JournalLog log = (await journal.getLogById(id))!;

      await journal.removeLog(id);
      expect(await journal.getLogById(id), isNull);

      await journal.restoreLog(log);
      final JournalLog restored = (await journal.getLogById(id))!;
      expect(restored.content, '推日：卧推 4×8');
      expect(restored.durationMinutes, 70);
      expect(restored.review, '下次加 2.5kg');
      expect(restored.type, JournalType.training);
    });

    test('restorePlan 恢复删除的计划，且历史记录仍然在', () async {
      final int planId =
          await journal.addPlan(type: JournalType.study, title: '数学一轮');
      final int logId = await journal.saveLog(
        type: JournalType.study,
        date: DateTime(2026, 10, 3),
        content: '第三章',
        planId: planId,
      );
      final JournalPlan plan = (await journal.getPlanById(planId))!;

      await journal.removePlan(planId);
      expect(await journal.getPlanById(planId), isNull);
      expect(
        (await journal.getLogById(logId))!.planId,
        isNull,
        reason: '删计划只解绑，记录本身要留下',
      );

      await journal.restorePlan(plan);
      expect((await journal.getPlanById(planId))!.title, '数学一轮');
      expect(await journal.getLogById(logId), isNotNull);
    });
  });
}
