/// 日期与时间处理工具。
///
/// 数据层里凡是"某一天"的概念（任务截止、数据记录、日记、日志），
/// 统一用当天 00:00 的本地时间表示，方便做唯一索引和范围查询。
class DayUtils {
  const DayUtils._();

  /// 归一化到当天 00:00:00.000（本地时区）。
  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 当天最后一刻 23:59:59.999。
  static DateTime dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String two(int v) => v.toString().padLeft(2, '0');

  /// `2026-10-03`
  static String formatDate(DateTime d) =>
      '${d.year}-${two(d.month)}-${two(d.day)}';

  /// `10月3日`
  static String formatMonthDay(DateTime d) => '${d.month}月${d.day}日';

  /// `星期五`
  static String weekday(DateTime d) =>
      '星期${const <String>['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1]}';

  /// `今天` / `昨天` / `前天` / `10月3日`（跨年时带上年份）
  static String friendlyDate(DateTime d, {DateTime? now}) {
    final DateTime today = dayStart(now ?? DateTime.now());
    final int diff = today.difference(dayStart(d)).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    if (d.year == today.year) return formatMonthDay(d);
    return '${d.year}年${formatMonthDay(d)}';
  }

  /// `2026-10-03 09:30`
  static String formatDateTime(DateTime d) =>
      '${formatDate(d)} ${two(d.hour)}:${two(d.minute)}';

  /// `09:30`
  static String formatClock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  /// 把「时间点」类型的值（当天的分钟数，0~1439）格式化成 `23:30`。
  static String minutesToClock(num minutes) {
    final int m = minutes.round().clamp(0, 1439);
    return '${two(m ~/ 60)}:${two(m % 60)}';
  }

  /// `HH:mm` 解析成当天分钟数；解析失败返回 null。
  static int? clockToMinutes(String text) {
    final List<String> parts = text.trim().split(':');
    if (parts.length != 2) return null;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  /// 时长格式化：90 → `1小时30分`，45 → `45分钟`。
  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return m == 0 ? '$h小时' : '$h小时$m分';
  }

  /// 最近 n 天的日期列表（含今天），按时间升序。
  static List<DateTime> lastDays(int n, {DateTime? from}) {
    final DateTime today = dayStart(from ?? DateTime.now());
    return List<DateTime>.generate(
      n,
      (int i) => today.subtract(Duration(days: n - 1 - i)),
    );
  }
}
