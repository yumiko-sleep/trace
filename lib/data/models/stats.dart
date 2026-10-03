/// 数据层对外返回的轻量统计模型。
library;

/// 某一天的任务完成情况。
class DayTaskStats {
  const DayTaskStats({required this.total, required this.done});

  final int total;
  final int done;

  /// 完成度 0.0 ~ 1.0
  double get progress => total == 0 ? 0 : done / total;

  bool get isEmpty => total == 0;
}

/// 某个分类下（今日 / 今年 / 人生）的目标汇总。
class GoalCategoryStats {
  const GoalCategoryStats({
    required this.total,
    required this.done,
    required this.averageProgress,
  });

  /// 目标总数
  final int total;

  /// 已完成数量
  final int done;

  /// 平均进度 0.0 ~ 1.0
  final double averageProgress;

  bool get isEmpty => total == 0;
}

/// 日记板块的汇总。
class DiaryStats {
  const DiaryStats({
    required this.days,
    required this.entries,
    required this.images,
  });

  /// 写过的天数
  final int days;

  /// 日记篇数
  final int entries;

  /// 配图总数
  final int images;
}

/// 趋势图上的一个点。
class MetricTrendPoint {
  const MetricTrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// 一段时间内某个数据项的统计结果。
class MetricSummary {
  const MetricSummary({
    required this.recordedDays,
    required this.totalDays,
    required this.average,
    required this.best,
  });

  /// 有记录的天数
  final int recordedDays;

  /// 统计范围内的总天数
  final int totalDays;

  /// 平均值（无记录时为 null）
  final double? average;

  /// 最好的一天（数值最小或最大，由调用方决定语义）
  final MetricTrendPoint? best;

  double get coverage => totalDays == 0 ? 0 : recordedDays / totalDays;
}
