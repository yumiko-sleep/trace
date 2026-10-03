import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/goal_dao.dart';
import 'package:trace/data/dao/task_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/repositories/goal_repository.dart';
import 'package:trace/data/repositories/task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  late GoalRepository goals;

  setUp(() {
    db = openTestDatabase();
    tasks = TaskRepository(TaskDao(db));
    goals = GoalRepository(GoalDao(db));
  });

  tearDown(() => db.close());

  group('TaskRepository', () {
    test('新增 / 查询 / 编辑 / 删除', () async {
      final int id = await tasks.add(title: '  背 50 个单词  ', note: '早上做');
      final Task? created = await tasks.getById(id);
      expect(created, isNotNull);
      expect(created!.title, '背 50 个单词', reason: '标题首尾空格应被去掉');
      expect(created.note, '早上做');
      expect(created.isDone, isFalse);
      expect(created.priority, 1, reason: '默认优先级为中');

      await tasks.edit(id, title: '背 80 个单词', priority: 2);
      final Task edited = (await tasks.getById(id))!;
      expect(edited.title, '背 80 个单词');
      expect(edited.priority, 2);
      expect(edited.note, '早上做', reason: '没传的字段不应该被清空');

      expect(await tasks.remove(id), 1);
      expect(await tasks.getById(id), isNull);
    });

    test('勾选完成会写入完成时间，取消勾选会清空', () async {
      final int id = await tasks.add(title: '跑步 3 公里');
      await tasks.markDone(id, true);

      Task task = (await tasks.getById(id))!;
      expect(task.isDone, isTrue);
      expect(task.doneAt, isNotNull);

      await tasks.markDone(id, false);
      task = (await tasks.getById(id))!;
      expect(task.isDone, isFalse);
      expect(task.doneAt, isNull);
    });

    test('toggleDone 来回切换', () async {
      final int id = await tasks.add(title: '写日记');
      await tasks.toggleDone(id);
      expect((await tasks.getById(id))!.isDone, isTrue);
      await tasks.toggleDone(id);
      expect((await tasks.getById(id))!.isDone, isFalse);
    });

    test('按日期过滤（同一天不同时刻都算今天）', () async {
      final DateTime today = DateTime(2026, 10, 3, 15, 30);
      await tasks.add(title: '今天的事', dueDate: DateTime(2026, 10, 3, 8));
      await tasks.add(
        title: '另一件今天的事',
        dueDate: DateTime(2026, 10, 3, 23, 59),
      );
      await tasks.add(title: '明天的事', dueDate: DateTime(2026, 10, 4));

      final List<Task> todayTasks = await tasks.getByDay(today);
      expect(todayTasks.length, 2);
      expect(
        todayTasks.map((Task t) => t.title),
        containsAll(<String>['今天的事', '另一件今天的事']),
      );
    });

    test('statsOfDay 统计完成度', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final int a = await tasks.add(title: 'A', dueDate: day);
      final int b = await tasks.add(title: 'B', dueDate: day);
      await tasks.add(title: 'C', dueDate: day);
      await tasks.markDone(a, true);
      await tasks.markDone(b, true);

      final stats = await tasks.statsOfDay(day);
      expect(stats.total, 3);
      expect(stats.done, 2);
      expect(stats.progress, closeTo(2 / 3, 0.0001));
    });

    test('clearDone 只删已完成', () async {
      final int a = await tasks.add(title: 'A');
      await tasks.add(title: 'B');
      await tasks.markDone(a, true);

      expect(await tasks.clearDone(), 1);
      final List<Task> rest = await tasks.getAll();
      expect(rest.length, 1);
      expect(rest.single.title, 'B');
    });

    test('moveIncompleteTo 把未完成任务顺延到另一天', () async {
      final DateTime today = DateTime(2026, 10, 3);
      final DateTime tomorrow = DateTime(2026, 10, 4);
      final int a = await tasks.add(title: 'A', dueDate: today);
      await tasks.add(title: 'B', dueDate: today);
      await tasks.markDone(a, true);

      expect(await tasks.moveIncompleteTo(today, tomorrow), 1);
      expect((await tasks.getByDay(today)).length, 1, reason: '只剩已完成的那条');
      expect((await tasks.getByDay(tomorrow)).length, 1);
      expect((await tasks.getByDay(tomorrow)).single.title, 'B');
    });

    test('任务可关联目标；目标被删后关联自动置空（外键 setNull）', () async {
      final int goalId = await goals.add(
        title: '今年读完 24 本书',
        category: GoalCategory.thisYear,
      );
      final int taskId = await tasks.add(title: '读《xxx》', goalId: goalId);

      expect((await tasks.getById(taskId))!.goalId, goalId);
      expect((await tasks.getByGoal(goalId)).length, 1);

      await goals.remove(goalId);
      final Task orphan = (await tasks.getById(taskId))!;
      expect(orphan.goalId, isNull);
      expect(orphan.title, '读《xxx》', reason: '任务本身不应该被删掉');
    });

    test('watchByDay 是响应式流，新增任务后能收到新值', () async {
      final DateTime day = DateTime(2026, 10, 3);
      final Stream<List<Task>> stream = tasks.watchByDay(day);

      final Future<void> expectation = expectLater(
        stream,
        emitsThrough(predicate<List<Task>>((List<Task> l) => l.length == 1)),
      );

      await tasks.add(title: '第一条', dueDate: day);
      await expectation;
    });
  });
}
