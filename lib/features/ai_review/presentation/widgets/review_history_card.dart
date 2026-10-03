import 'package:flutter/material.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/swipe_to_delete.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 历史复盘卡：日期 + 状态 + 一句话总结（或失败原因），左滑删除、点击看全文。
class ReviewHistoryCard extends StatelessWidget {
  const ReviewHistoryCard({
    super.key,
    required this.review,
    required this.headline,
    required this.onTap,
    required this.onDelete,
  });

  final AiReview review;

  /// 已经解析好的摘要（调用方从 content 里取）。
  final String headline;

  final VoidCallback onTap;
  final VoidCallback onDelete;

  Color _statusColor(AppScheme c) => switch (review.status) {
        AiReviewStatus.success => c.mintDeep,
        AiReviewStatus.pending => c.sky,
        AiReviewStatus.failed => c.danger,
      };

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final bool isToday = DayUtils.isSameDay(review.date, DateTime.now());
    final Color color = _statusColor(c);
    final String summary = review.status == AiReviewStatus.failed
        ? (review.errorMessage.trim().isEmpty ? '生成失败' : review.errorMessage.trim())
        : (headline.trim().isEmpty
            ? (review.status == AiReviewStatus.pending ? '正在生成…' : '（没有摘要）')
            : headline.trim());

    return SwipeToDelete(
      onDelete: onDelete,
      onTap: onTap,
      radius: 22,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isToday ? c.violet.withValues(alpha: 0.35) : c.line,
            ),
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
                  Text(
                    DayUtils.friendlyDate(review.date),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    DayUtils.weekday(review.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: c.inkFaint,
                    ),
                  ),
                  const Spacer(),
                  _Tag(text: review.status.label, color: color),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: c.inkFaint,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.8,
                  height: 1.6,
                  color: review.status == AiReviewStatus.failed
                      ? c.danger
                      : c.inkSoft,
                ),
              ),
              if (review.model.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${review.provider} · ${review.model}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: c.inkFaint,
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
