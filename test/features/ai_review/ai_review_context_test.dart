import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/utils/day_utils.dart';
import 'package:trace/data/dao/diary_dao.dart';
import 'package:trace/data/dao/goal_dao.dart';
import 'package:trace/data/dao/journal_dao.dart';
import 'package:trace/data/dao/metric_dao.dart';
import 'package:trace/data/dao/task_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/models/stats.dart';
import 'package:trace/data/repositories/diary_repository.dart';
import 'package:trace/data/repositories/goal_repository.dart';
import 'package:trace/data/repositories/journal_repository.dart';
import 'package:trace/data/repositories/metric_repository.dart';
import 'package:trace/data/repositories/task_repository.dart';
import 'package:trace/data/seed/built_in_metrics.dart';
import 'package:trace/features/ai_review/domain/ai_review_context.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  late GoalRepository goals;
  late DiaryRepository diary;
  late MetricRepository metrics;
  late JournalRepository journal;

  final DateTime today = DayUtils.dayStart(DateTime.now());
  final DateTime yesterday = today.subtract(const Duration(days: 1));

  setUp(() {
    db = openTestDatabase();
    tasks = TaskRepository(TaskDao(db));
    goals = GoalRepository(GoalDao(db));
    diary = DiaryRepository(DiaryDao(db));
    metrics = MetricRepository(MetricDao(db));
    journal = JournalRepository(JournalDao(db));
  });

  tearDown(() => db.close());

  /// 与 AiReviewDataSource 完全一致的采集方式（只是不经过 Riverpod）。
  Future<Map<String, dynamic>> buildContext() async {
    final DateTime from = today.subtract(
      const Duration(days: AiReviewContextBuilder.trendDays - 1),
    );
    final List<Task> allTasks = await tasks.getAll();
    final List<Goal> allGoals = await goals.getAll();
    final Map<int, DayTaskStats> linked = await tasks.linkedStatsByGoal();
    final DiaryEntry? entry = await diary.getByDay(today);
    final int images =
        entry == null ? 0 : (await diary.getImages(entry.id)).length;
    final List<DiaryEntry> recentDiary = (await diary.getAll())
        .where((DiaryEntry e) => !DayUtils.dayStart(e.date).isBefore(from))
        .toList(growable: false);

    final List<MetricDefinition> defs = await metrics.getDefinitions();
    final Map<int, List<MetricTrendPoint>> trends =
        <int, List<MetricTrendPoint>>{};
    for (final MetricDefinition def in defs) {
      trends[def.id] =
          await metrics.getTrend(def.id, days: 7, end: today);
    }

    final List<JournalPlan> plans = <JournalPlan>[];
    final List<JournalLog> logs = <JournalLog>[];
    final List<JournalLog> recentLogs = <JournalLog>[];
    for (final JournalType type in JournalType.values) {
      plans.addAll(await journal.getPlans(type));
      final List<JournalLog> typeLogs = await journal.getLogs(type);
      logs.addAll(typeLogs);
      recentLogs.addAll(
        typeLogs.where(
          (JournalLog l) => !DayUtils.dayStart(l.date).isBefore(from),
        ),
      );
    }

    return AiReviewContextBuilder.build(
      day: today,
      tasks: allTasks,
      goals: allGoals,
      goalTaskStats: linked,
      diary: entry,
      diaryImageCount: images,
      recentDiary: recentDiary,
      metricDefinitions: defs,
      metricTrends: trends,
      journalPlans: plans,
      journalLogs: logs,
      recentJournalLogs: recentLogs,
    );
  }

  group('任务 / 目标', () {
    test('统计完成率，并把逾期未完成的单独列出', () async {
      final int goalId = await goals.add(
        title: '跑完半马',
        category: GoalCategory.thisYear,
        progress: 0.5,
        deadline: today.add(const Duration(days: 30)),
      );

      await tasks.add(title: '写周报', dueDate: today);
      final int runId = await tasks.add(
        title: '慢跑 5 公里',
        dueDate: today,
        goalId: goalId,
        priority: 2,
      );
      await tasks.markDone(runId, true);
      await tasks.add(title: '交房租', dueDate: yesterday);

      final Map<String, dynamic> ctx = await buildContext();
      final Map<String, dynamic> t = ctx['tasks'] as Map<String, dynamic>;

      expect(ctx['for_date'], DayUtils.formatDate(today));
      expect(ctx['weekday'], DayUtils.weekday(today));
      expect(t['total'], 2, reason: '只算当天的任务');
      expect(t['completed'], 1);
      expect(t['completion_rate'], 0.5);

      final List<dynamic> items = t['items'] as List<dynamic>;
      expect(items.length, 2);
      final Map<String, dynamic> run =
          items.firstWhere((dynamic e) => e['title'] == '慢跑 5 公里')
              as Map<String, dynamic>;
      expect(run['done'], isTrue);
      expect(run['priority'], '高', reason: '2 → 高');
      expect(run['goal'], '跑完半马');

      final List<dynamic> overdue = t['overdue_open'] as List<dynamic>;
      expect(overdue.length, 1);
      expect((overdue.first as Map<String, dynamic>)['days_overdue'], 1);

      final Map<String, dynamic> g = ctx['goals'] as Map<String, dynamic>;
      expect(g['total'], 1);
      expect(g['average_progress'], 0.5);
      final Map<String, dynamic> goal =
          (g['items'] as List<dynamic>).first as Map<String, dynamic>;
      expect(goal['level'], '今年目标');
      expect(goal['status'], '进行中');
      expect(goal['progress_percent'], 50);
      expect(goal['days_left'], 30);
      expect(goal['linked_tasks'], '1/1');
    });
  });

  group('日记', () {
    test('当天日记 + 最近 7 天摘要 + 配图数量', () async {
      await diary.saveEntry(
        date: today,
        content: '今天把数据板块做完了，有点成就感。',
        mood: Mood.happy,
        imagePaths: <String>['/data/diary/1.jpg', '/data/diary/2.jpg'],
      );
      await diary.saveEntry(
        date: yesterday,
        content: '昨天有点累。',
        mood: Mood.sad,
      );

      final Map<String, dynamic> ctx = await buildContext();
      final Map<String, dynamic> d = ctx['diary'] as Map<String, dynamic>;

      expect(d['has_entry'], isTrue);
      expect(d['mood'], '开心');
      expect(d['content'], contains('成就感'));
      expect(d['content_length'], greaterThan(10));
      expect(d['images'], 2);

      final List<dynamic> recent = d['recent_7d'] as List<dynamic>;
      expect(recent.length, 1, reason: '当天不重复进摘要');
      expect((recent.first as Map<String, dynamic>)['mood'], '低落');
    });

    test('没写日记时 has_entry 为 false 且进入数据质量说明', () async {
      final Map<String, dynamic> ctx = await buildContext();
      expect((ctx['diary'] as Map<String, dynamic>)['has_entry'], isFalse);
      expect(
        (ctx['data_quality'] as List<dynamic>).join(),
        contains('今天没有写日记'),
      );
    });
  });

  group('数据趋势表格', () {
    test('每个数据项都给 7 行数字表格，缺记录填 null 并统计缺失', () async {
      await metrics.setValueByKey(
        key: BuiltInMetricKeys.readingTime,
        day: today,
        value: 25,
      );
      await metrics.setValueByKey(
        key: BuiltInMetricKeys.readingTime,
        day: today.subtract(const Duration(days: 2)),
        value: 40,
      );
      await metrics.setValueByKey(
        key: BuiltInMetricKeys.screenTime,
        day: today,
        value: 200,
      );

      final Map<String, dynamic> ctx = await buildContext();
      final Map<String, dynamic> m = ctx['metrics'] as Map<String, dynamic>;
      expect(m['window_days'], 7);

      final List<dynamic> todayList = m['today'] as List<dynamic>;
      final Map<String, dynamic> reading = todayList
          .firstWhere((dynamic e) => e['name'] == '阅读时长') as Map<String, dynamic>;
      expect(reading['value'], 25);
      expect(reading['value_display'], '25分钟');
      expect(reading['target'], 30);
      expect(reading['achieved'], isFalse, reason: '25 < 30 未达标');
      expect(reading['direction'], '越高越好');

      final Map<String, dynamic> screen = todayList
          .firstWhere((dynamic e) => e['name'] == '屏幕使用') as Map<String, dynamic>;
      expect(screen['achieved'], isFalse, reason: '200 > 180 未达标');
      expect(screen['direction'], '越低越好');

      final List<dynamic> tables = m['trend_tables'] as List<dynamic>;
      final Map<String, dynamic> readingTable = tables
          .firstWhere((dynamic e) => e['name'] == '阅读时长') as Map<String, dynamic>;
      expect(readingTable['recorded_days'], 2);
      expect(readingTable['missing_days'], 5);
      expect(readingTable['average'], 32.5);
      expect(readingTable['best'], 40);
      expect(readingTable['achieved_days'], 1);

      final List<dynamic> rows = readingTable['table'] as List<dynamic>;
      expect(rows.length, 7);
      expect(
        (rows.last as Map<String, dynamic>)['date'],
        DayUtils.formatDate(today),
        reason: '表格按日期升序，最后一行是今天',
      );
      expect((rows.last as Map<String, dynamic>)['value'], 25);
      expect(
        rows.where((dynamic e) => (e as Map<String, dynamic>)['value'] == null)
            .length,
        5,
        reason: '缺记录的日子是 null，模型据此判断断档',
      );

      final String quality =
          (ctx['data_quality'] as List<dynamic>).join();
      expect(quality, contains('屏幕使用 最近 7 天只有 1 天有记录'));
      expect(quality, contains('饮食热量 最近 7 天没有任何记录'));
    });
    test('最近 7 天没有任何记录的数据项不进趋势表', () async {
      await metrics.setValueByKey(
        key: BuiltInMetricKeys.readingTime,
        day: today,
        value: 10,
      );

      final Map<String, dynamic> ctx = await buildContext();
      final Map<String, dynamic> m = ctx['metrics'] as Map<String, dynamic>;
      final List<dynamic> tables = m['trend_tables'] as List<dynamic>;

      expect(tables.length, 1, reason: '只发有记录的那一项，省 token');
      expect((tables.first as Map<String, dynamic>)['name'], '阅读时长');
      expect(
        (m['today'] as List<dynamic>).length,
        5,
        reason: '当天列表仍然列全部数据项（无记录显示 null）',
      );
    });
  });

  group('上下文瘦身', () {
    test('超长日记会截断，避免上下文膨胀拖慢生成', () async {
      final String long = '很长的日记。' * 400;
      await diary.saveEntry(date: today, content: long, mood: Mood.calm);

      final Map<String, dynamic> ctx = await buildContext();
      final Map<String, dynamic> d = ctx['diary'] as Map<String, dynamic>;

      expect(d['content_truncated'], isTrue);
      expect(d['content_length'], long.length);
      expect(
        (d['content'] as String).length,
        lessThanOrEqualTo(AiReviewContextBuilder.maxDiaryChars + 1),
      );
    });
  });

  group('日志', () {
    test('当天学习/训练记录 + 计划名 + 最近 7 天时长', () async {
      final int planId = await journal.addPlan(
        type: JournalType.study,
        title: '数学一轮复习',
      );
      await journal.saveLog(
        type: JournalType.study,
        date: today,
        planId: planId,
        content: '第三章 + 30 道题',
        durationMinutes: 60,
        review: '卡在特征值',
      );
      await journal.saveLog(
        type: JournalType.training,
        date: yesterday,
        content: '推日：卧推 4×8',
        durationMinutes: 45,
      );

      final Map<String, dynamic> ctx = await buildContext();
      final Map<String, dynamic> j = ctx['journal'] as Map<String, dynamic>;
      final Map<String, dynamic> day = j['today'] as Map<String, dynamic>;
      final Map<String, dynamic> study = day['study'] as Map<String, dynamic>;

      expect(study['plan'], '数学一轮复习');
      expect(study['minutes'], 60);
      expect(study['review'], '卡在特征值');
      expect(day['training'], isNull, reason: '昨天的训练不算今天');

      final Map<String, dynamic> weekly =
          j['weekly_minutes'] as Map<String, dynamic>;
      expect(weekly['study'], 60);
      expect(weekly['training'], 45);

      final List<dynamic> recent = j['recent_7d'] as List<dynamic>;
      expect(recent.length, 1);
      expect((recent.first as Map<String, dynamic>)['type'], '训练日志');

      final Map<String, dynamic> plans = j['plans'] as Map<String, dynamic>;
      expect((plans['study'] as List<dynamic>).length, 1);
    });
  });

  test('encode() 输出可再次解析的缩进 JSON', () async {
    final Map<String, dynamic> ctx = await buildContext();
    final String json = AiReviewContextBuilder.encode(ctx);
    expect(json, contains('\n  '));
    final Map<String, dynamic> decoded =
        jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['schema'], 'trace.daily_review.v1');
    expect(decoded['for_date'], DayUtils.formatDate(today));
  });
}
