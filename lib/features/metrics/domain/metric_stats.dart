import '../../../core/utils/day_utils.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';

/// ============================================================
/// 「数据」板块的纯逻辑：时间窗口、数值格式化、区间统计。
///
/// 这里刻意不碰 Riverpod / Widget，方便直接写单元测试。
/// ============================================================

/// 趋势图的时间窗口。
enum MetricRange {
  /// 最近 7 天
  week,

  /// 最近 30 天
  month,

  /// 最近 365 天
  year,
}

extension MetricRangeX on MetricRange {
  /// 按钮上的短标签
  String get label => switch (this) {
        MetricRange.week => '周',
        MetricRange.month => '月',
        MetricRange.year => '年',
      };

  /// 卡片标题里的说明
  String get longLabel => switch (this) {
        MetricRange.week => '最近 7 天',
        MetricRange.month => '最近 30 天',
        MetricRange.year => '最近一年',
      };

  /// 窗口天数（含今天）
  int get days => switch (this) {
        MetricRange.week => 7,
        MetricRange.month => 30,
        MetricRange.year => 365,
      };

  /// 横轴大约标几个刻度，避免文字挤在一起。
  int get axisTickCount => switch (this) {
        MetricRange.week => 7,
        MetricRange.month => 6,
        MetricRange.year => 6,
      };
}

/// 屏幕使用时间这类指标「越小越好」；其余指标默认越大越好。
///
/// 判断逻辑放在这里集中维护，图表、达标率、最优一天都从这里取值。
bool metricLowerIsBetter(MetricDefinition def) =>
    def.key == 'screen_time' || def.unit == 'kg';

/// 去掉多余小数：25.0 → `25`，25.5 → `25.5`。
String trimNumber(num value) {
  final double v = value.toDouble();
  if ((v - v.roundToDouble()).abs() < 0.001) return v.round().toString();
  return v.toStringAsFixed(1);
}

/// 完整展示值：时间点 → `23:30`，时长 → `1小时30分`，其余 → `180 分钟`。
String formatMetricValue(MetricDefinition def, double value) {
  switch (def.valueType) {
    case MetricValueType.clock:
      return DayUtils.minutesToClock(value);
    case MetricValueType.duration:
      if (def.unit.isEmpty || def.unit == '分钟') {
        return DayUtils.formatDuration(value.round());
      }
      return '${trimNumber(value)} ${def.unit}';
    case MetricValueType.number:
      return def.unit.isEmpty
          ? trimNumber(value)
          : '${trimNumber(value)} ${def.unit}';
  }
}

/// 图表坐标轴用的短文本：`23:30` / `90m` / `1.5h` / `1850`。
String formatMetricShort(MetricDefinition def, double value) {
  switch (def.valueType) {
    case MetricValueType.clock:
      return DayUtils.minutesToClock(value);
    case MetricValueType.duration:
      if (value >= 120) {
        final double hours = value / 60;
        return '${trimNumber(hours)}h';
      }
      return '${value.round()}m';
    case MetricValueType.number:
      return value >= 1000 ? value.round().toString() : trimNumber(value);
  }
}

/// 某个值是否达标（没设目标值时一律算未达标，由调用方决定是否使用）。
bool metricAchieved(
  MetricDefinition def,
  double value, {
  bool? lowerIsBetter,
}) {
  final double? target = def.targetValue;
  if (target == null) return false;
  final bool lower = lowerIsBetter ?? metricLowerIsBetter(def);
  return lower ? value <= target : value >= target;
}

/// 一段时间内的统计结果。
class MetricStats {
  const MetricStats({
    required this.recordedDays,
    required this.totalDays,
    required this.sum,
    required this.average,
    required this.best,
    required this.achievedDays,
    required this.streak,
    required this.target,
    required this.lowerIsBetter,
  });

  /// 有记录的天数
  final int recordedDays;

  /// 窗口总天数
  final int totalDays;

  final double sum;

  /// 平均值（无记录时为 null）
  final double? average;

  /// 最好的一天（无记录时为 null）
  final MetricTrendPoint? best;

  /// 达标天数（没设目标值时恒为 0）
  final int achievedDays;

  /// 连续记录天数（从窗口内最后一条记录往前数）
  final int streak;

  final double? target;
  final bool lowerIsBetter;

  bool get isEmpty => recordedDays == 0;

  /// 记录覆盖率 0.0 ~ 1.0
  double get coverage => totalDays == 0 ? 0 : recordedDays / totalDays;

  /// 达标率 0.0 ~ 1.0（没设目标值时为 null）
  double? get achievedRate {
    if (target == null || recordedDays == 0) return null;
    return achievedDays / recordedDays;
  }
}

/// 计算一段时间内的统计结果。
///
/// [points] 只需包含有记录的日子（缺记录的日子不补 0）；
/// [streak] 从其中最新的一条记录开始往前数，中间断档即停止。
MetricStats computeMetricStats({
  required List<MetricTrendPoint> points,
  required int totalDays,
  double? target,
  bool lowerIsBetter = false,
}) {
  if (points.isEmpty) {
    return MetricStats(
      recordedDays: 0,
      totalDays: totalDays,
      sum: 0,
      average: null,
      best: null,
      achievedDays: 0,
      streak: 0,
      target: target,
      lowerIsBetter: lowerIsBetter,
    );
  }

  final List<MetricTrendPoint> sorted = List<MetricTrendPoint>.of(points)
    ..sort((MetricTrendPoint a, MetricTrendPoint b) => a.date.compareTo(b.date));

  double sum = 0;
  int achieved = 0;
  MetricTrendPoint best = sorted.first;
  for (final MetricTrendPoint p in sorted) {
    sum += p.value;
    if (target != null) {
      final bool ok = lowerIsBetter ? p.value <= target : p.value >= target;
      if (ok) achieved++;
    }
    final bool better =
        lowerIsBetter ? p.value < best.value : p.value > best.value;
    if (better) best = p;
  }

  // 连续记录天数：从最后一天往前找，日期必须严格相邻。
  int streak = 1;
  for (int i = sorted.length - 1; i > 0; i--) {
    final int gap =
        DayUtils.dayStart(sorted[i].date).difference(DayUtils.dayStart(sorted[i - 1].date)).inDays;
    if (gap == 1) {
      streak++;
    } else {
      break;
    }
  }

  return MetricStats(
    recordedDays: sorted.length,
    totalDays: totalDays,
    sum: sum,
    average: sum / sorted.length,
    best: best,
    achievedDays: achieved,
    streak: streak,
    target: target,
    lowerIsBetter: lowerIsBetter,
  );
}

/// 录入页的进度：今天填了几项。
class DayMetricProgress {
  const DayMetricProgress({required this.recorded, required this.total});

  final int recorded;
  final int total;

  bool get isEmpty => total == 0;

  double get progress => total == 0 ? 0 : recorded / total;
}

/// 自定义数据项可选的颜色（和全局配色保持一致）。
class MetricPalette {
  const MetricPalette._();

  static const List<int> values = <int>[
    0xFF3DDC97, // 薄荷绿
    0xFF22C1DC, // 青蓝
    0xFF2E9BF7, // 天蓝
    0xFF5B7CFA, // 靛蓝
    0xFF8B6CF7, // 紫罗兰
    0xFFF2A93B, // 琥珀
    0xFFF26D6D, // 珊瑚红
  ];
}
