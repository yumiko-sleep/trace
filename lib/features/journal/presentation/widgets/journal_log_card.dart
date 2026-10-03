import 'package:flutter/material.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/swipe_to_delete.dart';
import '../../../../data/db/app_database.dart';
import '../../domain/journal_stats.dart';
import 'journal_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 历史记录卡：日期 + 时长 + 关联计划 + 正文 + 复盘。
class JournalLogCard extends StatelessWidget {
  const JournalLogCard({
    super.key,
    required this.log,
    required this.onTap,
    required this.onDelete,
    this.planTitle,
  });

  final JournalLog log;
  final String? planTitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color color = journalColor(log.type);
    final String content = log.content.trim();
    final String review = log.review.trim();
    final bool isToday = DayUtils.isSameDay(log.date, DateTime.now());

    return SwipeToDelete(
      onDelete: onDelete,
      onTap: onTap,
      radius: 22,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isToday ? color.withValues(alpha: 0.35) : c.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.ink.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DayUtils.friendlyDate(log.date),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DayUtils.weekday(log.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: c.inkFaint,
                    ),
                  ),
                  const Spacer(),
                  if (log.durationMinutes != null)
                    JournalTag(
                      text: formatMinutes(log.durationMinutes!),
                      color: c.sky,
                      icon: Icons.timer_outlined,
                    ),
                ],
              ),
              if (content.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: c.ink,
                  ),
                ),
              ],
              if (planTitle != null) ...<Widget>[
                const SizedBox(height: 10),
                JournalTag(
                  text: planTitle!,
                  color: color,
                  icon: Icons.link_rounded,
                ),
              ],
              if (review.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.insights_rounded,
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '复盘',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        review,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.7,
                          color: c.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
