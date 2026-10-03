import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/stats.dart';
import '../../domain/metric_stats.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 趋势折线图：渐变描边 + 渐变填充 + 目标线 + 触摸提示。
///
/// 缺记录的日子不补 0，曲线直接跨过去（避免「没记录」被误读成「值为 0」）。
class MetricTrendChart extends StatelessWidget {
  const MetricTrendChart({
    super.key,
    required this.def,
    required this.range,
    required this.points,
    this.end,
    this.height = 208,
  });

  final MetricDefinition def;
  final MetricRange range;
  final List<MetricTrendPoint> points;
  final DateTime? end;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final DateTime base = DayUtils.dayStart(end ?? DateTime.now());
    final DateTime start = base.subtract(Duration(days: range.days - 1));
    final Color color = Color(def.colorHex);
    final bool lower = metricLowerIsBetter(def);
    final double? target = def.targetValue;

    final List<FlSpot> spots = <FlSpot>[];
    for (final MetricTrendPoint p in points) {
      final int index =
          DayUtils.dayStart(p.date).difference(start).inDays;
      if (index >= 0 && index < range.days) {
        spots.add(FlSpot(index.toDouble(), p.value));
      }
    }
    spots.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));

    if (spots.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.show_chart_rounded,
                size: 30,
                color: color.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 10),
              Text(
                '这段时间还没有记录',
                style: TextStyle(fontSize: 12.5, color: c.inkFaint),
              ),
            ],
          ),
        ),
      );
    }

    // ---------- 纵轴范围 ----------
    double low = spots.first.y;
    double high = spots.first.y;
    for (final FlSpot s in spots) {
      if (s.y < low) low = s.y;
      if (s.y > high) high = s.y;
    }
    if (target != null) {
      if (target < low) low = target;
      if (target > high) high = target;
    }
    final double span = high - low;
    final double pad = span == 0 ? (high.abs() * 0.12 + 1) : span * 0.28;
    double minY = (low - pad).clamp(0, double.infinity).toDouble();
    double maxY = high + pad;
    if (def.valueType == MetricValueType.clock) {
      minY = (minY / 60).floorToDouble() * 60;
      maxY = (maxY / 60).ceilToDouble() * 60;
    }
    if (maxY - minY < 1) maxY = minY + 1;

    final int bottomInterval =
        (range.days / range.axisTickCount).round().clamp(1, range.days);
    final double yInterval = (maxY - minY) / 4;

    String bottomLabel(DateTime d) => range == MetricRange.year
        ? '${d.month}月'
        : '${d.month}/${d.day}';

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (range.days - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: c.line,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: def.valueType == MetricValueType.clock ? 42 : 36,
                interval: yInterval,
                getTitlesWidget: (double value, TitleMeta meta) => SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    formatMetricShort(def, value),
                    style: TextStyle(
                      fontSize: 10,
                      color: c.inkFaint,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.round();
                  if (index < 0 ||
                      index >= range.days ||
                      index % bottomInterval != 0) {
                    return const SizedBox.shrink();
                  }
                  final DateTime date = start.add(Duration(days: index));
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      bottomLabel(date),
                      style: TextStyle(
                        fontSize: 10,
                        color: c.inkFaint,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: target == null
                ? const <HorizontalLine>[]
                : <HorizontalLine>[
                    HorizontalLine(
                      y: target,
                      color: c.amber.withValues(alpha: 0.75),
                      strokeWidth: 1.2,
                      dashArray: <int>[6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: c.amber,
                        ),
                        labelResolver: (HorizontalLine line) =>
                            lower ? '目标 ≤' : '目标 ≥',
                      ),
                    ),
                  ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) =>
                  c.ink.withValues(alpha: 0.90),
              getTooltipItems: (List<LineBarSpot> touched) =>
                  touched.map((LineBarSpot spot) {
                final DateTime date =
                    start.add(Duration(days: spot.x.round()));
                return LineTooltipItem(
                  '${DayUtils.formatMonthDay(date)}\n'
                  '${formatMetricValue(def, spot.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.32,
              preventCurveOverShooting: true,
              barWidth: 2.8,
              isStrokeCapRound: true,
              gradient: LinearGradient(
                colors: <Color>[color, color.withValues(alpha: 0.75)],
              ),
              dotData: FlDotData(
                show: spots.length <= 14,
                getDotPainter: (
                  FlSpot spot,
                  double percent,
                  LineChartBarData bar,
                  int index,
                ) =>
                    FlDotCirclePainter(
                  radius: 3.2,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: color,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    color.withValues(alpha: 0.30),
                    color.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        // 切换数据项 / 周月年时，曲线会自己补一段过渡，而不是硬切（fl_chart 1.x 的参数在 widget 上）
        duration: AppMotion.slow,
        curve: AppMotion.emphasized,
      ),
    );
  }
}
