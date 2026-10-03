import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/utils/day_utils.dart';
import '../../../core/widgets/bounce_tap.dart';
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/section_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../domain/metric_stats.dart';
import '../providers/metric_providers.dart';
import 'widgets/daily_input_card.dart';
import 'widgets/metric_editor_sheet.dart';
import 'widgets/metric_stats_row.dart';
import 'widgets/metric_trend_chart.dart';
import 'widgets/metric_visuals.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// 板块 4：数据（睡眠 / 起床 / 屏幕时间 / 热量 / 阅读 + 自定义）。
class MetricsPage extends ConsumerWidget {
  const MetricsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScheme c = context.scheme;
    final List<MetricDefinition> defs =
        ref.watch(metricDefinitionsProvider).valueOrNull ??
            const <MetricDefinition>[];
    final MetricDefinition? selected = ref.watch(selectedMetricProvider);
    final MetricRange range = ref.watch(metricRangeProvider);
    final AsyncValue<List<MetricTrendPoint>> asyncPoints =
        ref.watch(metricTrendProvider);
    final MetricStats? stats = ref.watch(metricStatsProvider);
    final Map<int, double> todayValues =
        ref.watch(dayMetricValuesProvider).valueOrNull ?? const <int, double>{};
    final DateTime entryDay = ref.watch(metricEntryDayProvider);

    return SectionScaffold(
      title: '数据',
      subtitle: '看不见的变化，用图表替你记住。',
      icon: Icons.query_stats_rounded,
      gradient: c.metrics,
      bottomPadding: 120,
      floatingActionButton: _AddMetricButton(
        onTap: () => showMetricEditorSheet(context),
      ),
      children: <Widget>[
        const DailyInputCard(),
        const SizedBox(height: 26),
        SectionHeader(
          title: '趋势',
          subtitle: selected == null
              ? '先添加一个数据项'
              : '${selected.name} · ${range.longLabel}',
          trailing: BounceTap(
            onTap: () => showMetricManageSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: c.indigo.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: c.indigo.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.tune_rounded, size: 14, color: c.indigo),
                  const SizedBox(width: 5),
                  Text(
                    '管理',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (defs.isNotEmpty) ...<Widget>[
          MetricSelector(
            defs: defs,
            selectedId: selected?.id,
            onSelected: (int id) =>
                ref.read(selectedMetricIdProvider.notifier).state = id,
          ),
          const SizedBox(height: 14),
        ],
        if (selected == null)
          const PlaceholderCard(
            icon: Icons.stacked_line_chart_rounded,
            title: '还没有数据项',
            description: '点右下角「新增数据项」，或者到「管理」里恢复内置的 5 项，'
                '之后每天花 20 秒填一填，趋势图就会自己长出来。',
          )
        else
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    MetricIconBadge(
                      iconKey: selected.iconKey,
                      color: Color(selected.colorHex),
                      size: 34,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            selected.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            metricMetaText(
                              typeLabel: selected.valueType.label,
                              unit: selected.unit,
                              target: selected.targetValue,
                              lowerIsBetter: metricLowerIsBetter(selected),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (todayValues.containsKey(selected.id))
                      MetricTag(
                        text: '今日 ${formatMetricValue(selected, todayValues[selected.id]!)}',
                        color: Color(selected.colorHex),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _RangeSelector(
                  value: range,
                  color: Color(selected.colorHex),
                  onChanged: (MetricRange r) =>
                      ref.read(metricRangeProvider.notifier).state = r,
                ),
                const SizedBox(height: 16),
                MetricTrendChart(
                  def: selected,
                  range: range,
                  points: asyncPoints.valueOrNull ?? const <MetricTrendPoint>[],
                ),
                const SizedBox(height: 16),
                if (stats != null)
                  MetricStatsRow(def: selected, stats: stats)
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        const SizedBox(height: 16),
        InfoNote(
          text: '点一行填一个值，填错了再点一次可以改或清除；'
              '顶部左右箭头能往前翻，用来补录前几天的数据（不能记未来的日子）。'
              '长按某一行可以直接改它的名称、目标值和颜色。'
              '当前录入的是 ${DayUtils.friendlyDate(entryDay)}。',
        ),
      ],
    );
  }
}

/// 数据项选择器：一排可横向滚动的胶囊。
class MetricSelector extends StatelessWidget {
  const MetricSelector({
    super.key,
    required this.defs,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MetricDefinition> defs;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: defs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final MetricDefinition def = defs[index];
          final bool active = def.id == selectedId;
          final Color color = Color(def.colorHex);
          return BounceTap(
            onTap: () => onSelected(def.id),
            haptic: false,
            scale: 0.97,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.14)
                    : c.fieldFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? color.withValues(alpha: 0.55) : c.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? color : color.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    def.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? color : c.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 周 / 月 / 年 切换。
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final MetricRange value;
  final Color color;
  final ValueChanged<MetricRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.isDark ? c.card : c.bgBottom.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: <Widget>[
          for (final MetricRange r in MetricRange.values)
            Expanded(
              child: BounceTap(
                onTap: () => onChanged(r),
                haptic: false,
                scale: 0.98,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == r
                        ? color.withValues(alpha: 0.92)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: value == r ? Colors.white : c.inkFaint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 「新增数据项」悬浮按钮。
class _AddMetricButton extends StatelessWidget {
  const _AddMetricButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return BounceTap(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: c.metrics,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.violet.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 7),
            Text(
              '新增数据项',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
