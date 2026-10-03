import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/services/backup/backup_codec.dart';
import 'package:trace/data/services/backup/trace_backup.dart';

import '../helpers/test_database.dart';

/// 每个用例：source 当「导出前的手机」，target 当「重装后的手机」。
void main() {
  const BackupCodec codec = BackupCodec();
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = openTestDatabase();
    target = openTestDatabase();
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('dump → restore：10 张表逐行完整往返（含内置数据项）', () async {
    await _seed(source);

    final TraceBackup before = await codec.dump(source, appVersion: '0.2.1+1');
    expect(
      before.counts.keys.toSet(),
      BackupTables.ordered.toSet(),
      reason: '10 张表都该出现在备份里',
    );
    expect(before.totalRows, greaterThan(0));

    await codec.restore(target, before);
    final TraceBackup after = await codec.dump(target, appVersion: '0.2.1+1');

    for (final String table in BackupTables.ordered) {
      expect(
        _sorted(after.rows[table]),
        _sorted(before.rows[table]),
        reason: '「${BackupTables.labels[table]}」往返后不一致',
      );
    }
  });

  test('关键字段往返：可空枚举 / 外键 / 毫秒级时间', () async {
    await _seed(source);
    await codec.restore(target, await codec.dump(source, appVersion: 'x'));

    final List<Goal> goals = await target.select(target.goals).get();
    final int lifeId =
        goals.firstWhere((Goal g) => g.title == '想成为长期主义者').id;
    final Goal yearGoal = goals.firstWhere((Goal g) => g.title == '今年跑 500 公里');

    expect(yearGoal.parentId, lifeId, reason: '目标的自引用外键要保住');
    expect(yearGoal.status, GoalStatus.paused);
    expect(yearGoal.progress, 0);
    expect(yearGoal.deadline, null);
    expect(goals.length, 2);

    final Task task = (await target.select(target.tasks).get()).single;
    expect(task.goalId, yearGoal.id, reason: '任务 → 目标的外键要保住');
    expect(task.isDone, isTrue);
    expect(task.doneAt, DateTime(2026, 10, 3, 21, 30));
    expect(task.priority, 2);
    expect(task.note, '含上周遗留');

    final List<DiaryEntry> entries = await target.select(target.diaryEntries).get();
    final DiaryEntry withMood =
        entries.firstWhere((DiaryEntry e) => e.mood == Mood.happy);
    final DiaryEntry noMood = entries.firstWhere((DiaryEntry e) => e.mood == null);
    expect(withMood.content, '今天写了备份功能\n第二行');
    expect(noMood.content, '心情没记', reason: '可空枚举为 null 也要原样还原');

    final JournalPlan plan =
        (await target.select(target.journalPlans).get()).single;
    final JournalLog log = (await target.select(target.journalLogs).get()).single;
    expect(log.durationMinutes, 35);
    expect(log.planId, plan.id, reason: '日志 → 计划的外键要保住');
    expect(log.review, '注意力还行');

    final MetricRecord record =
        (await target.select(target.metricRecords).get()).single;
    expect(record.value, 8.5);
    expect(record.date, DateTime(2026, 10, 3));

    final AiReview review = (await target.select(target.aiReviews).get()).single;
    expect(review.status, AiReviewStatus.success);
    expect(review.model, 'deepseek-v4-pro');
    expect(review.snapshotJson, '{"schema":"trace.daily_review.v1"}');

    final AppSetting setting =
        (await target.select(target.appSettings).get()).single;
    expect(setting.key, 'theme_mode');
    expect(setting.value, 'dark');
  });

  test('restore 会先清空现有数据，不是「追加」', () async {
    await _seed(source);
    // 目标库里先塞一条备份中没有的任务
    await target.into(target.tasks).insert(
          TasksCompanion.insert(
            title: '这条不该活下来',
            id: const Value<int>(999),
          ),
        );

    await codec.restore(target, await codec.dump(source, appVersion: 'x'));

    final List<Task> tasks = await target.select(target.tasks).get();
    expect(tasks.length, 1);
    expect(tasks.single.title, '写周报');
    expect(tasks.single.id, isNot(999));
  });

  test('恢复期间外键是关掉的：先写子行也不会炸', () async {
    // 故意把顺序搅乱：任务的 goalId 指向的目标排在后面才写入
    final TraceBackup backup = TraceBackup(
      rows: <String, List<Map<String, dynamic>>>{
        BackupTables.tasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': '悬空引用也能写进去',
            'note': '',
            'dueDate': null,
            'isDone': false,
            'doneAt': null,
            'goalId': 7,
            'priority': 1,
            'sortOrder': 0,
            'createdAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
            'updatedAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
          },
        ],
        BackupTables.goals: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'title': '后写入的目标',
            'description': '',
            'category': GoalCategory.today.index,
            'progress': 0.0,
            'deadline': null,
            'status': GoalStatus.active.index,
            'parentId': null,
            'sortOrder': 0,
            'createdAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
            'updatedAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
          },
        ],
      },
      exportedAt: DateTime(2026, 10, 3),
      appVersion: 'x',
    );

    await codec.restore(target, backup);

    expect((await target.select(target.tasks).get()).single.goalId, 7);
    expect((await target.select(target.goals).get()).single.id, 7);

    // 恢复结束后外键必须重新打开：删掉目标，任务的 goalId 应该被置空
    // （外键没恢复的话，这里还会是 7）
    await (target.delete(target.goals)
          ..where(($GoalsTable g) => g.id.equals(7)))
        .go();
    final Task afterDelete = (await target.select(target.tasks).get()).single;
    expect(afterDelete.goalId, null, reason: '外键没恢复的话 goalId 还会挂在已删除的目标上');
  });

  test('配图路径：导出剥成文件名，导入按新目录拼回来', () async {
    await _seed(source);
    final TraceBackup backup = await codec.dump(source, appVersion: 'x');
    expect(
      backup.rows[BackupTables.diaryImages]!.single['path'],
      '1700000000000_0_0.jpg',
      reason: '备份里不能出现本机的绝对路径',
    );

    await codec.restore(
      target,
      backup,
      resolveImagePath: (String name) => '/data/x/diary_images/$name',
    );
    final DiaryImage image =
        (await target.select(target.diaryImages).get()).single;
    expect(image.path, '/data/x/diary_images/1700000000000_0_0.jpg');
    expect(image.caption, '跑步轨迹');
    expect(image.sortOrder, 1);
  });

  test('备份里的未知表被忽略，不会让导入失败', () async {
    await _seed(source);
    final TraceBackup backup = await codec.dump(source, appVersion: 'x');
    backup.rows['future_table'] = <Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'whatever': 'v2 才有的东西'},
    ];

    await codec.restore(target, backup);
    expect((await target.select(target.tasks).get()).length, 1);
  });

  group('格式校验', () {
    test('schema 不对 → BackupFormatException', () {
      expect(
        () => TraceBackup.decode(utf8.encode('{"schema":"other.app.v1"}')),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('没有 schema / 没有 data → BackupFormatException', () {
      expect(
        () => TraceBackup.decode(utf8.encode('{"data":{}}')),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => TraceBackup.decode(utf8.encode('{"schema":"$kTraceBackupSchema"}')),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('顶层不是对象 / 不是 JSON → BackupFormatException', () {
      expect(
        () => TraceBackup.decode(utf8.encode('[1,2,3]')),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => TraceBackup.decode(utf8.encode('我不是 JSON')),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('encode → decode 是自反的', () async {
      await _seed(source);
      final TraceBackup backup = await codec.dump(source, appVersion: '0.2.1+1');
      final TraceBackup again = TraceBackup.decode(backup.encode());

      expect(again.totalRows, backup.totalRows);
      expect(again.imageCount, backup.imageCount);
      expect(again.appVersion, '0.2.1+1');
      expect(
        again.exportedAt!.millisecondsSinceEpoch,
        backup.exportedAt!.millisecondsSinceEpoch,
      );
      expect(
        _sorted(again.rows[BackupTables.diaryEntries]),
        _sorted(backup.rows[BackupTables.diaryEntries]),
      );
    });

    test('行数统计与中文清单', () {
      const TraceBackup backup = TraceBackup(
        rows: <String, List<Map<String, dynamic>>>{
          BackupTables.tasks: <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
            <String, dynamic>{'id': 2},
          ],
          BackupTables.goals: <Map<String, dynamic>>[],
          BackupTables.aiReviews: <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
          ],
        },
      );
      expect(backup.counts, <String, int>{
        BackupTables.tasks: 2,
        BackupTables.aiReviews: 1,
      });
      expect(backup.totalRows, 3);
      expect(backup.countOf(BackupTables.goals), 0);
      expect(backup.countOf('没有这张表'), 0);
    });
  });
}

/// 同一张表的两批行，按序列化后的字符串排序再比，忽略读取顺序差异。
List<String> _sorted(List<Map<String, dynamic>>? rows) =>
    (rows ?? const <Map<String, dynamic>>[])
        .map((Map<String, dynamic> r) => jsonEncode(r))
        .toList()
      ..sort();

/// 造一份「什么都有」的样本数据。
Future<void> _seed(AppDatabase db) async {
  final int lifeGoal = await db.into(db.goals).insert(
        GoalsCompanion.insert(
          title: '想成为长期主义者',
          description: const Value<String>('十年尺度'),
          category: GoalCategory.life,
          progress: const Value<double>(0.35),
          deadline: Value<DateTime?>(DateTime(2035, 1, 1)),
        ),
      );
  final int yearGoal = await db.into(db.goals).insert(
        GoalsCompanion.insert(
          title: '今年跑 500 公里',
          category: GoalCategory.thisYear,
          status: const Value<GoalStatus>(GoalStatus.paused),
          parentId: Value<int?>(lifeGoal),
        ),
      );

  await db.into(db.tasks).insert(
        TasksCompanion.insert(
          title: '写周报',
          note: const Value<String>('含上周遗留'),
          dueDate: Value<DateTime?>(DateTime(2026, 10, 3)),
          isDone: const Value<bool>(true),
          doneAt: Value<DateTime?>(DateTime(2026, 10, 3, 21, 30)),
          goalId: Value<int?>(yearGoal),
          priority: const Value<int>(2),
        ),
      );

  final int entryId = await db.into(db.diaryEntries).insert(
        DiaryEntriesCompanion.insert(
          date: DateTime(2026, 10, 3),
          content: const Value<String>('今天写了备份功能\n第二行'),
          mood: const Value<Mood?>(Mood.happy),
        ),
      );
  await db.into(db.diaryEntries).insert(
        DiaryEntriesCompanion.insert(
          date: DateTime(2026, 10, 2),
          content: const Value<String>('心情没记'),
        ),
      );
  await db.into(db.diaryImages).insert(
        DiaryImagesCompanion.insert(
          entryId: entryId,
          path: '/data/user/0/com.trace.app.trace/app_flutter/diary_images/'
              '1700000000000_0_0.jpg',
          caption: const Value<String>('跑步轨迹'),
          sortOrder: const Value<int>(1),
        ),
      );

  final int metricId = await db.into(db.metricDefinitions).insert(
        MetricDefinitionsCompanion.insert(
          key: 'mood_score',
          name: '心情分',
          unit: const Value<String>('分'),
          valueType: MetricValueType.number,
          colorHex: const Value<int>(0xFF7C5CFF),
          targetValue: const Value<double?>(10),
          sortOrder: const Value<int>(9),
        ),
      );
  await db.into(db.metricRecords).insert(
        MetricRecordsCompanion.insert(
          metricId: metricId,
          date: DateTime(2026, 10, 3),
          value: 8.5,
        ),
      );

  final int planId = await db.into(db.journalPlans).insert(
        JournalPlansCompanion.insert(
          type: JournalType.study,
          title: '每天 30 分钟英语',
          content: const Value<String>('早上：单词\n晚上：听力'),
          isActive: const Value<bool>(true),
          sortOrder: const Value<int>(1),
        ),
      );
  await db.into(db.journalLogs).insert(
        JournalLogsCompanion.insert(
          type: JournalType.study,
          date: DateTime(2026, 10, 3),
          planId: Value<int?>(planId),
          content: const Value<String>('背了 60 个单词'),
          durationMinutes: const Value<int?>(35),
          review: const Value<String>('注意力还行'),
        ),
      );

  await db.into(db.aiReviews).insert(
        AiReviewsCompanion.insert(
          date: DateTime(2026, 10, 3),
          provider: const Value<String>('deepseek'),
          model: const Value<String>('deepseek-v4-pro'),
          content: const Value<String>('{"headline":"今天不错"}'),
          status: AiReviewStatus.success,
          snapshotJson: const Value<String>('{"schema":"trace.daily_review.v1"}'),
        ),
      );

  await db.into(db.appSettings).insert(
        AppSettingsCompanion.insert(key: 'theme_mode', value: 'dark'),
      );
}
