import 'dart:convert';

import '../../../core/utils/day_utils.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../../metrics/domain/metric_stats.dart';

/// ============================================================
/// 把当天（以及最近 7 天）的全部数据打包成结构化 JSON。
///
/// 设计原则：
/// 1. 字段名用英文 + snake_case，方便任何模型稳定引用；
/// 2. 数值一律给原始数字（分钟、kcal、以分钟数表示的时刻），
///    人话展示放在 `*_display` 字段里，避免模型把「1小时30分」当数字算错；
/// 3. 趋势以 **数字表格** 传入（每行一天，缺记录填 null），
///    让模型自己判断上升 / 下降 / 断档，而不是我们提前下结论；
/// 4. 缺什么数据在 data_quality 里明说，减少模型编造。
///
/// 这个类是纯函数，不碰数据库 / Riverpod，可直接单测。
/// ============================================================
class AiReviewContextBuilder {
  const AiReviewContextBuilder._();

  static const String schema = 'trace.daily_review.v1';

  /// 趋势窗口天数（一周）
  static const int trendDays = 7;

  /// 控制单次请求的体积，直接决定生成速度：这些上限之外的都截断/略过。
  static const int maxTaskItems = 20;
  static const int maxOverdueItems = 10;
  static const int maxGoalItems = 20;
  static const int maxDiaryChars = 1500;

  static const List<String> _priorityLabels = <String>['低', '中', '高'];

  static Map<String, dynamic> build({
    required DateTime day,
    List<Task> tasks = const <Task>[],
    List<Goal> goals = const <Goal>[],
    Map<int, DayTaskStats> goalTaskStats = const <int, DayTaskStats>{},
    DiaryEntry? diary,
    int diaryImageCount = 0,
    List<DiaryEntry> recentDiary = const <DiaryEntry>[],
    List<MetricDefinition> metricDefinitions = const <MetricDefinition>[],
    Map<int, List<MetricTrendPoint>> metricTrends =
        const <int, List<MetricTrendPoint>>{},
    List<JournalPlan> journalPlans = const <JournalPlan>[],
    List<JournalLog> journalLogs = const <JournalLog>[],
    List<JournalLog> recentJournalLogs = const <JournalLog>[],
  }) {
    final DateTime d0 = DayUtils.dayStart(day);
    final Map<int, String> goalTitles = <int, String>{
      for (final Goal g in goals) g.id: g.title,
    };

    final List<Task> todayTasks = tasks
        .where(
          (Task t) =>
              t.dueDate != null && DayUtils.isSameDay(t.dueDate!, d0),
        )
        .toList(growable: false);
    final List<Task> overdueTasks = tasks
        .where(
          (Task t) =>
              !t.isDone &&
              t.dueDate != null &&
              DayUtils.dayStart(t.dueDate!).isBefore(d0),
        )
        .toList(growable: false);

    return <String, dynamic>{
      'schema': schema,
      'for_date': DayUtils.formatDate(d0),
      'weekday': DayUtils.weekday(d0),
      'tasks': _tasksJson(todayTasks, overdueTasks, goalTitles, d0),
      'goals': _goalsJson(goals, goalTaskStats, d0),
      'diary': _diaryJson(diary, diaryImageCount, recentDiary, d0),
      'metrics': _metricsJson(metricDefinitions, metricTrends, d0),
      'journal': _journalJson(journalPlans, journalLogs, recentJournalLogs, d0),
      'data_quality': _dataQuality(
        todayTasks: todayTasks,
        diary: diary,
        metricDefinitions: metricDefinitions,
        metricTrends: metricTrends,
        journalLogs: journalLogs,
        recentDiary: recentDiary,
      ),
    };
  }

  /// 便于预览 / 存进 snapshot_json 的缩进版 JSON。
  static String encode(Map<String, dynamic> context) =>
      const JsonEncoder.withIndent('  ').convert(context);

  // ---------------- 任务 ----------------

  static Map<String, dynamic> _tasksJson(
    List<Task> todayTasks,
    List<Task> overdueTasks,
    Map<int, String> goalTitles,
    DateTime d0,
  ) {
    final int total = todayTasks.length;
    final int done = todayTasks.where((Task t) => t.isDone).length;
    final List<Task> shownTasks = todayTasks.take(maxTaskItems).toList();
    final List<Task> shownOverdue =
        overdueTasks.take(maxOverdueItems).toList();
    return <String, dynamic>{
      'total': total,
      'completed': done,
      'completion_rate':
          total == 0 ? 0 : double.parse((done / total).toStringAsFixed(2)),
      'items': <Map<String, dynamic>>[
        for (final Task t in shownTasks)
          <String, dynamic>{
            'title': t.title,
            'done': t.isDone,
            'priority': _priorityLabels[
                t.priority.clamp(0, _priorityLabels.length - 1)],
            if (t.note.trim().isNotEmpty) 'note': _excerpt(t.note, 60),
            if (t.goalId != null) 'goal': goalTitles[t.goalId] ?? '已删除的目标',
          },
      ],
      if (total > shownTasks.length)
        'omitted_items': total - shownTasks.length,
      'overdue_open': <Map<String, dynamic>>[
        for (final Task t in shownOverdue)
          <String, dynamic>{
            'title': t.title,
            'due_date': DayUtils.formatDate(t.dueDate!),
            'days_overdue':
                d0.difference(DayUtils.dayStart(t.dueDate!)).inDays,
          },
      ],
      if (overdueTasks.length > shownOverdue.length)
        'omitted_overdue': overdueTasks.length - shownOverdue.length,
    };
  }

  // ---------------- 目标 ----------------

  static Map<String, dynamic> _goalsJson(
    List<Goal> goals,
    Map<int, DayTaskStats> goalTaskStats,
    DateTime d0,
  ) {
    if (goals.isEmpty) {
      return <String, dynamic>{
        'total': 0,
        'items': <Map<String, dynamic>>[],
      };
    }
    final double avg = goals.fold<double>(
          0,
          (double acc, Goal g) => acc + g.progress,
        ) /
        goals.length;

    final List<Goal> shown = goals.take(maxGoalItems).toList();

    return <String, dynamic>{
      'total': goals.length,
      'active': goals.where((Goal g) => g.status == GoalStatus.active).length,
      'done': goals.where((Goal g) => g.status == GoalStatus.done).length,
      'average_progress': double.parse(avg.toStringAsFixed(2)),
      'items': <Map<String, dynamic>>[
        for (final Goal g in shown)
          <String, dynamic>{
            'title': g.title,
            'level': g.category.label,
            'status': g.status.label,
            'progress_percent': (g.progress * 100).round(),
            if (g.deadline != null)
              'deadline': DayUtils.formatDate(g.deadline!),
            if (g.deadline != null)
              'days_left':
                  DayUtils.dayStart(g.deadline!).difference(d0).inDays,
            if (goalTaskStats[g.id] != null &&
                goalTaskStats[g.id]!.total > 0)
              'linked_tasks':
                  '${goalTaskStats[g.id]!.done}/${goalTaskStats[g.id]!.total}',
            if (g.description.trim().isNotEmpty)
              'description': _excerpt(g.description, 60),
          },
      ],
      if (goals.length > shown.length) 'omitted_items': goals.length - shown.length,
    };
  }

  // ---------------- 日记 ----------------

  static Map<String, dynamic> _diaryJson(
    DiaryEntry? diary,
    int imageCount,
    List<DiaryEntry> recentDiary,
    DateTime d0,
  ) {
    final List<Map<String, dynamic>> recent = <Map<String, dynamic>>[];
    for (final DiaryEntry e in recentDiary) {
      if (DayUtils.isSameDay(e.date, d0)) continue;
      recent.add(<String, dynamic>{
        'date': DayUtils.formatDate(e.date),
        'mood': e.mood?.label,
        'excerpt': _excerpt(e.content, 80),
      });
    }

    // 日记太长就截断：它是上下文里最容易膨胀的部分，
    // 而且模型只需要读懂「发生了什么」，不需要逐字全文。
    final String raw = diary?.content.trim() ?? '';
    final bool truncated = raw.length > maxDiaryChars;

    return <String, dynamic>{
      'has_entry': diary != null,
      if (diary != null) 'mood': diary.mood?.label,
      if (diary != null)
        'content': truncated ? '${raw.substring(0, maxDiaryChars)}…' : raw,
      if (diary != null) 'content_length': raw.length,
      if (truncated) 'content_truncated': true,
      if (diary != null) 'images': imageCount,
      'recent_7d': recent,
    };
  }

  // ---------------- 数据（含趋势数字表格） ----------------

  static Map<String, dynamic> _metricsJson(
    List<MetricDefinition> defs,
    Map<int, List<MetricTrendPoint>> trends,
    DateTime d0,
  ) {
    final List<DateTime> window = DayUtils.lastDays(trendDays, from: d0);

    final List<Map<String, dynamic>> todayValues = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> tables = <Map<String, dynamic>>[];

    for (final MetricDefinition def in defs) {
      final bool lower = metricLowerIsBetter(def);
      final List<MetricTrendPoint> points =
          trends[def.id] ?? const <MetricTrendPoint>[];

      double? todayValue;
      for (final MetricTrendPoint p in points) {
        if (DayUtils.isSameDay(p.date, d0)) {
          todayValue = p.value;
          break;
        }
      }

      todayValues.add(<String, dynamic>{
        'name': def.name,
        'unit': def.unit,
        'value': todayValue,
        'value_display':
            todayValue == null ? null : formatMetricValue(def, todayValue),
        'target': def.targetValue,
        'target_display': def.targetValue == null
            ? null
            : formatMetricValue(def, def.targetValue!),
        'direction': lower ? '越低越好' : '越高越好',
        'achieved': (def.targetValue == null || todayValue == null)
            ? null
            : (lower
                ? todayValue <= def.targetValue!
                : todayValue >= def.targetValue!),
      });

      final Map<DateTime, double> byDay = <DateTime, double>{
        for (final MetricTrendPoint p in points)
          DayUtils.dayStart(p.date): p.value,
      };

      final MetricStats stats = computeMetricStats(
        points: points,
        totalDays: trendDays,
        target: def.targetValue,
        lowerIsBetter: lower,
      );

      // 最近 7 天一条记录都没有的数据项就不发趋势表了（data_quality 里会说），
      // 少发一整张全 null 的表，省 token 也省时间。
      if (points.isEmpty) continue;

      tables.add(<String, dynamic>{
        'name': def.name,
        'unit': def.unit,
        'target': def.targetValue,
        'direction': lower ? '越低越好' : '越高越好',
        'recorded_days': stats.recordedDays,
        'missing_days': trendDays - stats.recordedDays,
        'average': stats.average == null
            ? null
            : double.parse(stats.average!.toStringAsFixed(1)),
        'best': stats.best?.value,
        'best_date': stats.best == null
            ? null
            : DayUtils.formatDate(stats.best!.date),
        'achieved_days': def.targetValue == null ? null : stats.achievedDays,
        // 数字表格：每行一天，缺记录就是 null（模型据此判断断档）
        'table': <Map<String, dynamic>>[
          for (final DateTime d in window)
            <String, dynamic>{
              'date': DayUtils.formatDate(d),
              'value': byDay[DayUtils.dayStart(d)],
            },
        ],
      });
    }

    return <String, dynamic>{
      'window_days': trendDays,
      'today': todayValues,
      'trend_tables': tables,
    };
  }

  // ---------------- 日志 ----------------

  static Map<String, dynamic> _journalJson(
    List<JournalPlan> plans,
    List<JournalLog> logs,
    List<JournalLog> recentLogs,
    DateTime d0,
  ) {
    String? planTitle(int? planId) {
      if (planId == null) return null;
      for (final JournalPlan p in plans) {
        if (p.id == planId) return p.title;
      }
      return null;
    }

    Map<String, dynamic>? logOf(JournalType type) {
      for (final JournalLog l in logs) {
        if (l.type == type && DayUtils.isSameDay(l.date, d0)) {
          return <String, dynamic>{
            'plan': planTitle(l.planId),
            'content': l.content.trim(),
            'minutes': l.durationMinutes,
            'review': l.review.trim(),
          };
        }
      }
      return null;
    }

    final DateTime from = d0.subtract(const Duration(days: trendDays - 1));
    int weeklyMinutes(JournalType type) => recentLogs
        .where(
          (JournalLog l) =>
              l.type == type && !DayUtils.dayStart(l.date).isBefore(from),
        )
        .fold<int>(0, (int acc, JournalLog l) => acc + (l.durationMinutes ?? 0));

    return <String, dynamic>{
      'today': <String, dynamic>{
        'study': logOf(JournalType.study),
        'training': logOf(JournalType.training),
      },
      'weekly_minutes': <String, dynamic>{
        'study': weeklyMinutes(JournalType.study),
        'training': weeklyMinutes(JournalType.training),
      },
      'recent_7d': <Map<String, dynamic>>[
        for (final JournalLog l in recentLogs)
          if (!DayUtils.isSameDay(l.date, d0))
            <String, dynamic>{
              'date': DayUtils.formatDate(l.date),
              'type': l.type.label,
              'content': _excerpt(l.content, 80),
              'minutes': l.durationMinutes,
              'has_review': l.review.trim().isNotEmpty,
            },
      ],
      'plans': <String, dynamic>{
        'study': <Map<String, dynamic>>[
          for (final JournalPlan p in plans)
            if (p.type == JournalType.study)
              <String, dynamic>{'title': p.title, 'active': p.isActive},
        ],
        'training': <Map<String, dynamic>>[
          for (final JournalPlan p in plans)
            if (p.type == JournalType.training)
              <String, dynamic>{'title': p.title, 'active': p.isActive},
        ],
      },
    };
  }

  // ---------------- 数据质量 ----------------

  static List<String> _dataQuality({
    required List<Task> todayTasks,
    required DiaryEntry? diary,
    required List<MetricDefinition> metricDefinitions,
    required Map<int, List<MetricTrendPoint>> metricTrends,
    required List<JournalLog> journalLogs,
    required List<DiaryEntry> recentDiary,
  }) {
    final List<String> notes = <String>[];
    if (todayTasks.isEmpty) notes.add('今天没有任何待办任务记录。');
    if (diary == null) notes.add('今天没有写日记。');
    if (recentDiary.isEmpty) notes.add('最近 7 天没有日记记录。');
    if (journalLogs.isEmpty) notes.add('今天没有学习/训练日志。');

    final List<String> sparse = <String>[];
    for (final MetricDefinition def in metricDefinitions) {
      final int recorded = metricTrends[def.id]?.length ?? 0;
      if (recorded == 0) {
        sparse.add('${def.name} 最近 7 天没有任何记录');
      } else if (recorded <= 2) {
        sparse.add('${def.name} 最近 7 天只有 $recorded 天有记录');
      }
    }
    if (sparse.isNotEmpty) {
      notes.add('数据项记录较少：${sparse.join('；')}。');
    }
    return notes;
  }

  static String _excerpt(String text, int max) {
    final String t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }
}
