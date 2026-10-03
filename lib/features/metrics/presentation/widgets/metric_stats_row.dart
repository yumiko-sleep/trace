import 'package:flutter/material.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../data/db/app_database.dart';
import '../../domain/metric_stats.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 趋势图下方的统计格子（2 × 2）。
class MetricStatsRow extends StatelessWidget {
  const MetricStatsRow({super.key, required this.def, required this.stats});

  final MetricDefinition def;
  final MetricStats stats;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final MetricStats s = stats;
    final double? rate = s.achievedRate;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: '平均',
                value: s.average == null
                    ? '—'
                    : formatMetricValue(def, s.average!),
                color: Color(def.colorHex),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: '记录天数',
                value: '${s.recordedDays}/${s.totalDays}',
                note: '覆盖 ${(s.coverage * 100).round()}%',
                color: c.sky,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: rate == null ? '连续记录' : '达标率',
                value: rate == null
                    ? '${s.streak} 天'
                    : '${(rate * 100).round()}%',
                note: rate == null ? null : '${s.achievedDays} 天达标',
                color: rate == null ? c.violet : c.mintDeep,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: s.lowerIsBetter ? '最低的一天' : '最高的一天',
                value: s.best == null ? '—' : formatMetricValue(def, s.best!.value),
                note: s.best == null ? null : DayUtils.friendlyDate(s.best!.date),
                color: c.indigo,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.note,
  });

  final String label;
  final String value;
  final String? note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}
