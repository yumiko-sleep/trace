import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/animated_count.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../domain/metric_stats.dart';
import '../../providers/metric_providers.dart';
import 'metric_editor_sheet.dart';
import 'metric_value_sheet.dart';
import 'metric_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 每日录入卡：一天一屏，把当天所有数据项填完。
///
/// 顶部的左右箭头可以往前翻，用来补录历史（不允许翻到未来）。
class DailyInputCard extends ConsumerWidget {
  const DailyInputCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScheme c = context.scheme;
    final DateTime day = ref.watch(metricEntryDayProvider);
    final AsyncValue<List<MetricDefinition>> asyncDefs =
        ref.watch(metricDefinitionsProvider);
    final List<MetricDefinition> defs =
        asyncDefs.valueOrNull ?? const <MetricDefinition>[];
    final Map<int, double> values =
        ref.watch(dayMetricValuesProvider).valueOrNull ?? const <int, double>{};
    final DayMetricProgress progress = ref.watch(dayMetricProgressProvider);

    final bool isToday = DayUtils.isSameDay(day, DateTime.now());

    return RepaintBoundary(
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        DayUtils.friendlyDate(day),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isToday ? '记录今天 · ${DayUtils.weekday(day)}' : DayUtils.weekday(day),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isToday)
                  BounceTap(
                    onTap: () => ref
                        .read(metricEntryDayProvider.notifier)
                        .state = DayUtils.dayStart(DateTime.now()),
                    child: MetricTag(text: '回到今天', color: c.sky),
                  ),
                const SizedBox(width: 8),
                _DayStepper(
                  onPrev: () => ref
                      .read(metricEntryDayProvider.notifier)
                      .state = day.subtract(const Duration(days: 1)),
                  // 不允许记录未来
                  onNext: isToday
                      ? null
                      : () => ref
                          .read(metricEntryDayProvider.notifier)
                          .state = day.add(const Duration(days: 1)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(child: MetricProgressBar(progress: progress.progress)),
                const SizedBox(width: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    AnimatedCount(
                      value: progress.recorded.toDouble(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.inkSoft,
                      ),
                    ),
                    Text(
                      '/${progress.total}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              progress.isEmpty
                  ? '还没有数据项'
                  : (progress.recorded >= progress.total
                      ? '今天全部填完啦'
                      : '还差 ${progress.total - progress.recorded} 项，点一行填一个'),
              style: TextStyle(fontSize: 11.5, color: c.inkFaint),
            ),
            const SizedBox(height: 8),
            const Divider(height: 22, thickness: 0.8),

            if (asyncDefs.isLoading && !asyncDefs.hasValue)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              )
            else if (defs.isEmpty)
              _EmptyMetrics(
                onRestore: () =>
                    ref.read(metricActionsProvider).restoreBuiltIns(),
              )
            else
              for (final MetricDefinition def in defs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MetricValueTile(
                    def: def,
                    value: values[def.id],
                    onTap: () => showMetricValueSheet(
                      context,
                      def: def,
                      day: day,
                      current: values[def.id],
                    ),
                    onLongPress: () => showMetricEditorSheet(context, def: def),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// 左右翻天的按钮组。
class _DayStepper extends StatelessWidget {
  const _DayStepper({required this.onPrev, required this.onNext});

  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      decoration: BoxDecoration(
        color: c.bgBottom.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
          ),
          Container(width: 1, height: 22, color: c.line),
          _StepButton(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final bool enabled = onTap != null;
    return BounceTap(
      onTap: onTap,
      haptic: enabled,
      child: SizedBox(
        width: 38,
        height: 36,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? c.inkSoft : c.line,
        ),
      ),
    );
  }
}

/// 一行数据项：图标 + 名称 + 类型信息 + 当天值。
class _MetricValueTile extends StatelessWidget {
  const _MetricValueTile({
    required this.def,
    required this.value,
    required this.onTap,
    required this.onLongPress,
  });

  final MetricDefinition def;
  final double? value;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color color = Color(def.colorHex);
    final bool lower = metricLowerIsBetter(def);
    final bool recorded = value != null;
    final bool achieved =
        recorded && def.targetValue != null && metricAchieved(def, value!);

    return BounceTap(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: false,
      scale: 0.99,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: recorded
              ? color.withValues(alpha: 0.07)
              : c.bgBottom.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: recorded ? color.withValues(alpha: 0.28) : c.line,
          ),
        ),
        child: Row(
          children: <Widget>[
            MetricIconBadge(iconKey: def.iconKey, color: color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    def.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metricMetaText(
                      typeLabel: def.valueType.label,
                      unit: def.unit,
                      target: def.targetValue,
                      lowerIsBetter: lower,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: c.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (recorded)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatMetricValue(def, value!),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (def.targetValue != null) ...<Widget>[
                    const SizedBox(height: 3),
                    MetricTag(
                      text: achieved ? '达标' : '未达标',
                      color: achieved ? c.mintDeep : c.amber,
                    ),
                  ],
                ],
              )
            else
              Text(
                '未记录',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.inkFaint,
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: c.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// 数据项被全部归档 / 删除后的空态。
class _EmptyMetrics extends StatelessWidget {
  const _EmptyMetrics({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: c.indigo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.query_stats_rounded,
              color: c.indigo,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '还没有数据项',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '可以把内置的 5 项恢复回来，也可以自己新增一项。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: c.inkFaint),
          ),
          const SizedBox(height: 14),
          BounceTap(
            onTap: onRestore,
            child: MetricTag(
              text: '恢复内置数据项',
              color: c.indigo,
              icon: Icons.restore_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
