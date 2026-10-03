import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/utils/day_utils.dart';

/// 纯逻辑测试，不依赖数据库，任何平台都能跑。
void main() {
  group('DayUtils', () {
    test('dayStart 归一到当天 00:00', () {
      final DateTime d = DayUtils.dayStart(DateTime(2026, 10, 3, 23, 45, 12));
      expect(d, DateTime(2026, 10, 3));
    });

    test('dayEnd 是当天最后一毫秒', () {
      final DateTime d = DayUtils.dayEnd(DateTime(2026, 10, 3, 1));
      expect(d, DateTime(2026, 10, 3, 23, 59, 59, 999));
    });

    test('isSameDay 跨时分秒仍为同一天', () {
      expect(
        DayUtils.isSameDay(
          DateTime(2026, 10, 3, 0, 1),
          DateTime(2026, 10, 3, 23, 59),
        ),
        isTrue,
      );
      expect(
        DayUtils.isSameDay(DateTime(2026, 10, 3), DateTime(2026, 10, 4)),
        isFalse,
      );
    });

    test('时间点（分钟数）与 HH:mm 互转', () {
      expect(DayUtils.minutesToClock(0), '00:00');
      expect(DayUtils.minutesToClock(1410), '23:30');
      expect(DayUtils.clockToMinutes('23:30'), 1410);
      expect(DayUtils.clockToMinutes('07:05'), 425);
    });

    test('非法时间格式返回 null', () {
      expect(DayUtils.clockToMinutes('25:00'), isNull);
      expect(DayUtils.clockToMinutes('12:70'), isNull);
      expect(DayUtils.clockToMinutes('abc'), isNull);
      expect(DayUtils.clockToMinutes('12'), isNull);
    });

    test('时长格式化', () {
      expect(DayUtils.formatDuration(45), '45分钟');
      expect(DayUtils.formatDuration(60), '1小时');
      expect(DayUtils.formatDuration(90), '1小时30分');
    });

    test('formatDate / formatClock 补零', () {
      expect(DayUtils.formatDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(DayUtils.formatClock(DateTime(2026, 1, 5, 9, 7)), '09:07');
    });

    test('lastDays 返回升序且含今天', () {
      final List<DateTime> days = DayUtils.lastDays(3, from: DateTime(2026, 10, 3, 15));
      expect(days.length, 3);
      expect(days.first, DateTime(2026, 10, 1));
      expect(days.last, DateTime(2026, 10, 3));
    });
  });
}
