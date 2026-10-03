import 'package:flutter/material.dart';

import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../data/models/enums.dart';
import '../../domain/journal_stats.dart';
import 'journal_visuals.dart';

/// 日志板块顶部汇总卡（渐变）。
class JournalSummaryCard extends StatelessWidget {
  const JournalSummaryCard({
    super.key,
    required this.type,
    required this.stats,
    required this.todayLogged,
    required this.onRecord,
  });

  final JournalType type;
  final JournalStats stats;
  final bool todayLogged;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final String recent = stats.recentMinutes == 0
        ? '还没有记录'
        : formatMinutes(stats.recentMinutes);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: journalGradient(type, c),
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: journalColor(type).withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                ),
                child: Icon(
                  type == JournalType.study
                      ? Icons.auto_stories_rounded
                      : Icons.directions_run_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '最近 ${stats.recentDays} 天 · ${type.shortLabel}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recent,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _MiniStat(label: '有记录', value: '${stats.totalDays} 天'),
              _MiniStat(label: '连续', value: '${stats.streak} 天'),
              _MiniStat(label: '累计', value: formatMinutes(stats.totalMinutes)),
              _MiniStat(label: '复盘', value: '${stats.reviewCount} 篇'),
            ],
          ),
          const SizedBox(height: 14),
          if (todayLogged)
            Text(
              '今天已经记过了，随时可以补充',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11.5,
              ),
            )
          else
            BounceTap(
              onTap: onRecord,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '今天还没记 → 现在就记',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
