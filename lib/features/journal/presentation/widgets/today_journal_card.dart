import 'package:flutter/material.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../domain/journal_stats.dart';
import 'journal_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 今日记录卡：记录正文 + 时长 + 关联计划，以及今天的复盘入口。
class TodayJournalCard extends StatelessWidget {
  const TodayJournalCard({
    super.key,
    required this.type,
    required this.log,
    required this.planTitle,
    required this.onRecord,
    required this.onReview,
  });

  final JournalType type;
  final JournalLog? log;
  final String? planTitle;
  final VoidCallback onRecord;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final JournalLog? entry = log;
    final bool hasLog = entry != null;
    final String content = entry?.content.trim() ?? '';
    final String review = entry?.review.trim() ?? '';
    final Color color = journalColor(type);

    return RepaintBoundary(
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                JournalIconBadge(type: type, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        type.todayTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${DayUtils.friendlyDate(DateTime.now())} · '
                        '${DayUtils.formatDate(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                JournalTag(
                  text: hasLog ? '已记录' : '未记录',
                  color: hasLog ? color : c.inkFaint,
                  icon: hasLog
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (content.isNotEmpty)
              Text(
                content,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: c.ink,
                ),
              )
            else
              Text(
                hasLog ? '今天还没写内容，可以补充' : '花一分钟写下来：${type.contentHint}',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: c.inkFaint,
                ),
              ),
            if (hasLog) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (entry.durationMinutes != null)
                    JournalTag(
                      text: formatMinutes(entry.durationMinutes!),
                      color: c.sky,
                      icon: Icons.timer_outlined,
                    ),
                  if (planTitle != null)
                    JournalTag(
                      text: planTitle!,
                      color: color,
                      icon: Icons.link_rounded,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            GradientButton(
              label: hasLog ? '编辑今天的记录' : '记录今天',
              icon: Icons.edit_calendar_rounded,
              height: 48,
              gradient: journalGradient(type, c),
              onPressed: onRecord,
            ),
            const SizedBox(height: 6),
            const Divider(height: 22, thickness: 0.8),
            Row(
              children: <Widget>[
                const SheetLabel('今天的复盘'),
                const Spacer(),
                if (review.isNotEmpty)
                  JournalTag(text: '已写', color: color, icon: Icons.done_rounded),
              ],
            ),
            const SizedBox(height: 10),
            if (review.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Text(
                  review,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    color: c.inkSoft,
                  ),
                ),
              )
            else
              Text(
                '还没写复盘。${type.reviewHint}',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: c.inkFaint,
                ),
              ),
            const SizedBox(height: 12),
            OutlinePillButton(
              label: review.isEmpty ? '写复盘' : '编辑复盘',
              icon: Icons.insights_rounded,
              color: color,
              onTap: onReview,
            ),
          ],
        ),
      ),
    );
  }
}

/// 「写复盘 / 编辑复盘」这类次要动作的描边胶囊按钮。
class OutlinePillButton extends StatelessWidget {
  const OutlinePillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BounceTap(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
