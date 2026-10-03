import '../../../core/utils/day_utils.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';

/// ============================================================
/// 「日志」板块的纯逻辑：文案映射、区间统计、连续记录天数。
///
/// 不依赖 Riverpod / Widget，可以直接写单元测试。
/// ============================================================

/// 学习 / 训练的界面文案与强调色（enums.dart 里的 label 是「学习日志」这种全称）。
extension JournalTypeUI on JournalType {
  /// 「学习」「训练」
  String get shortLabel =>
      this == JournalType.study ? '学习' : '训练';

  /// 「学习计划」「训练计划」
  String get planTitle => this == JournalType.study ? '学习计划' : '训练计划';

  /// 记录卡标题
  String get todayTitle =>
      this == JournalType.study ? '今天学到了什么' : '今天练了什么';

  /// 正文输入提示
  String get contentHint => this == JournalType.study
      ? '例如：线代第三章 + 30 道题，卡在特征值'
      : '例如：推日，卧推 4×8，卧推重量上不去了';

  /// 复盘输入提示
  String get reviewHint => this == JournalType.study
      ? '今天的复盘：哪些地方卡住了？明天怎么调整？'
      : '今天的复盘：动作感受如何？下次加多少重量？';

  /// 板块强调色（学习偏紫、训练偏蓝）
  int get accentHex => this == JournalType.study ? 0xFF8B6CF7 : 0xFF2E9BF7;
}

/// 日志汇总。
class JournalStats {
  const JournalStats({
    required this.logCount,
    required this.totalDays,
    required this.totalMinutes,
    required this.recentMinutes,
    required this.reviewCount,
    required this.streak,
    required this.recentDays,
  });

  /// 记录条数
  final int logCount;

  /// 有记录的天数
  final int totalDays;

  /// 累计时长（分钟）
  final int totalMinutes;

  /// 最近 [recentDays] 天的时长（分钟）
  final int recentMinutes;

  /// 写过复盘的天数
  final int reviewCount;

  /// 连续记录天数（从最近一条记录往前数）
  final int streak;

  final int recentDays;

  bool get isEmpty => logCount == 0;
}

/// 汇总一段时间内的记录。
///
/// [recentDays] 只影响 `recentMinutes`（默认最近 7 天）。
JournalStats computeJournalStats(
  List<JournalLog> logs, {
  int recentDays = 7,
  DateTime? now,
}) {
  if (logs.isEmpty) {
    return JournalStats(
      logCount: 0,
      totalDays: 0,
      totalMinutes: 0,
      recentMinutes: 0,
      reviewCount: 0,
      streak: 0,
      recentDays: recentDays,
    );
  }

  final List<JournalLog> sorted = List<JournalLog>.of(logs)
    ..sort((JournalLog a, JournalLog b) => a.date.compareTo(b.date));

  final DateTime today = DayUtils.dayStart(now ?? DateTime.now());
  final DateTime from = today.subtract(Duration(days: recentDays - 1));

  final Set<DateTime> days = <DateTime>{};
  int totalMinutes = 0;
  int recentMinutes = 0;
  int reviewCount = 0;
  for (final JournalLog log in sorted) {
    final DateTime day = DayUtils.dayStart(log.date);
    days.add(day);
    totalMinutes += log.durationMinutes ?? 0;
    if (!day.isBefore(from)) {
      recentMinutes += log.durationMinutes ?? 0;
    }
    if (log.review.trim().isNotEmpty) reviewCount++;
  }

  // 连续记录天数：日期必须严格相邻
  int streak = 1;
  for (int i = sorted.length - 1; i > 0; i--) {
    final int gap = DayUtils.dayStart(sorted[i].date)
        .difference(DayUtils.dayStart(sorted[i - 1].date))
        .inDays;
    if (gap == 1) {
      streak++;
    } else {
      break;
    }
  }

  return JournalStats(
    logCount: sorted.length,
    totalDays: days.length,
    totalMinutes: totalMinutes,
    recentMinutes: recentMinutes,
    reviewCount: reviewCount,
    streak: streak,
    recentDays: recentDays,
  );
}

/// 找出某一天的记录（同一天同类型约定只有一条）。
JournalLog? findLogOfDay(List<JournalLog> logs, DateTime day) {
  for (final JournalLog log in logs) {
    if (DayUtils.isSameDay(log.date, day)) return log;
  }
  return null;
}

/// 时长展示：90 → `1小时30分`。
String formatMinutes(int minutes) => DayUtils.formatDuration(minutes);
