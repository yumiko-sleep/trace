import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/dao/goal_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/repositories/goal_repository.dart';
import 'package:trace/data/repositories/task_repository.dart';
import 'package:trace/data/dao/task_dao.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late GoalRepository goals;
  late TaskRepository tasks;

  setUp(() {
    db = openTestDatabase();
    goals = GoalRepository(GoalDao(db));
    tasks = TaskRepository(TaskDao(db));
  });

  tearDown(() => db.close());

  group('GoalRepository', () {
    test('三个时间尺度的目标都能分别存取', () async {
      await goals.add(title: '今天读 20 页书', category: GoalCategory.today);
      await goals.add(title: '今年跑 500 公里', category: GoalCategory.thisYear);
      await goals.add(title: '成为能持续输出的人', category: GoalCategory.life);

      expect((await goals.getByCategory(GoalCategory.today)).length, 1);
      expect((await goals.getByCategory(GoalCategory.thisYear)).length, 1);
      expect((await goals.getByCategory(GoalCategory.life)).length, 1);
      expect((await goals.getAll()).length, 3);
    });

    test('新建目标默认状态为进行中、进度为 0', () async {
      final int id = await goals.add(title: '学完 Flutter', category: GoalCategory.thisYear);
      final Goal goal = (await goals.getById(id))!;
      expect(goal.status, GoalStatus.active);
      expect(goal.progress, 0);
      expect(goal.deadline, isNull);
    });

    test('进度会被夹在 0~1 之间', () async {
      final int id = await goals.add(title: '目标', category: GoalCategory.thisYear);

      await goals.updateProgress(id, 1.8);
      expect((await goals.getById(id))!.progress, 1.0);

      await goals.updateProgress(id, -0.5);
      expect((await goals.getById(id))!.progress, 0.0);

      await goals.updateProgress(id, 0.42);
      expect((await goals.getById(id))!.progress, closeTo(0.42, 0.0001));
    });

    test('edit 可以改状态、截止日期，也能清空截止日期', () async {
      final int id = await goals.add(title: '目标', category: GoalCategory.thisYear);
      await goals.edit(
        id,
        deadline: DateTime(2026, 12, 31),
        status: GoalStatus.paused,
      );
      Goal goal = (await goals.getById(id))!;
      expect(goal.deadline, DateTime(2026, 12, 31));
      expect(goal.status, GoalStatus.paused);

      await goals.edit(id, clearDeadline: true);
      goal = (await goals.getById(id))!;
      expect(goal.deadline, isNull);
    });

    test('子目标通过 parentId 关联；父目标删除后自动置空', () async {
      final int parent =
          await goals.add(title: '人生目标', category: GoalCategory.life);
      final int child = await goals.add(
        title: '今年目标',
        category: GoalCategory.thisYear,
        parentId: parent,
      );

      expect((await goals.getChildren(parent)).single.id, child);

      await goals.remove(parent);
      expect((await goals.getById(child))!.parentId, isNull);
    });

    test('markDone 把状态改成已完成', () async {
      final int id = await goals.add(title: '目标', category: GoalCategory.today);
      await goals.markDone(id);
      expect((await goals.getById(id))!.status, GoalStatus.done);
    });

    test('statsByCategory 汇总各分类完成情况', () async {
      final int a = await goals.add(title: 'A', category: GoalCategory.today);
      await goals.add(title: 'B', category: GoalCategory.today);
      await goals.markDone(a);

      final Map<GoalCategory, dynamic> stats = await goals.statsByCategory();
      expect(stats[GoalCategory.today]!.total, 2);
      expect(stats[GoalCategory.today]!.done, 1);
      expect(stats[GoalCategory.thisYear]!.total, 0);
    });

    test('目标进度与任务联动：任务数不因删目标而变化', () async {
      final int goalId =
          await goals.add(title: '今年读 24 本书', category: GoalCategory.thisYear);
      await tasks.add(title: '读第 1 本', goalId: goalId);
      await tasks.add(title: '读第 2 本', goalId: goalId);

      final List<Task> linked = await tasks.getByGoal(goalId);
      expect(linked.length, 2);

      await goals.updateProgress(goalId, linked.length / 24);
      expect(
        (await goals.getById(goalId))!.progress,
        closeTo(2 / 24, 0.0001),
      );
    });
  });
}
