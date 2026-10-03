import 'package:flutter_test/flutter_test.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/features/journal/domain/journal_stats.dart';

void main() {
  JournalLog log({
    required int id,
    required int day,
    JournalType type = JournalType.study,
    String content = '',
    int? duration,
    String review = '',
    int? planId,
  }) =>
      JournalLog(
        id: id,
        type: type,
        date: DateTime(2026, 10, day),
        planId: planId,
        content: content,
        durationMinutes: duration,
        review: review,
        createdAt: DateTime(2026, 10, day),
        updatedAt: DateTime(2026, 10, day),
      );

  group('computeJournalStats', () {
    test('没有记录时返回全 0', () {
      final JournalStats stats = computeJournalStats(const <JournalLog>[]);
      expect(stats.isEmpty, isTrue);
      expect(stats.logCount, 0);
      expect(stats.totalDays, 0);
      expect(stats.totalMinutes, 0);
      expect(stats.recentMinutes, 0);
      expect(stats.reviewCount, 0);
      expect(stats.streak, 0);
      expect(stats.recentDays, 7);
    });

    test('累计 / 最近 7 天时长 / 有记录天数 / 复盘篇数', () {
      final JournalStats stats = computeJournalStats(
        <JournalLog>[
          log(id: 1, day: 1, duration: 60, review: '第一天'),
          log(id: 2, day: 4, duration: 90),
          log(id: 3, day: 9, duration: 30),
        ],
        now: DateTime(2026, 10, 10),
      );
      expect(stats.logCount, 3);
      expect(stats.totalDays, 3);
      expect(stats.totalMinutes, 180);
      // 10 号的最近 7 天 = 4 号 ~ 10 号
      expect(stats.recentMinutes, 120, reason: '只算 4 号和 9 号的记录');
      expect(stats.reviewCount, 1);
    });

    test('同一天有多条也不算重复天数', () {
      final JournalStats stats = computeJournalStats(
        <JournalLog>[
          log(id: 1, day: 3, type: JournalType.study, duration: 30),
          log(id: 2, day: 3, type: JournalType.training, duration: 45),
        ],
      );
      expect(stats.logCount, 2);
      expect(stats.totalDays, 1);
      expect(stats.totalMinutes, 75);
    });

    test('连续记录天数：断档就停止', () {
      final JournalStats stats = computeJournalStats(
        <JournalLog>[
          log(id: 1, day: 1),
          log(id: 2, day: 2),
          // 3 号断档
          log(id: 3, day: 4),
          log(id: 4, day: 5),
          log(id: 5, day: 6),
        ],
      );
      expect(stats.streak, 3, reason: '从 6 号往前只有 4/5/6 号连着');
    });

    test('复盘篇数只算真正写了字的', () {
      final JournalStats stats = computeJournalStats(
        <JournalLog>[
          log(id: 1, day: 1, review: '写了'),
          log(id: 2, day: 2, review: '   '),
          log(id: 3, day: 3),
        ],
      );
      expect(stats.reviewCount, 1);
    });
  });

  group('findLogOfDay', () {
    test('按日期找记录，忽略具体时间', () {
      final List<JournalLog> logs = <JournalLog>[
        log(id: 1, day: 1),
        log(id: 2, day: 3),
      ];
      expect(findLogOfDay(logs, DateTime(2026, 10, 3, 23, 59))!.id, 2);
      expect(findLogOfDay(logs, DateTime(2026, 10, 5)), isNull);
    });
  });

  group('文案与格式化', () {
    test('学习 / 训练 的标签与强调色', () {
      expect(JournalType.study.shortLabel, '学习');
      expect(JournalType.training.shortLabel, '训练');
      expect(JournalType.study.planTitle, '学习计划');
      expect(JournalType.training.planTitle, '训练计划');
      expect(
        JournalType.study.accentHex,
        isNot(JournalType.training.accentHex),
      );
    });

    test('时长格式化', () {
      expect(formatMinutes(45), '45分钟');
      expect(formatMinutes(90), '1小时30分');
      expect(formatMinutes(120), '2小时');
    });
  });
}
