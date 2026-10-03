import 'package:flutter/material.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../domain/ai_review_report.dart';
import 'review_result_card.dart';
import 'snapshot_sheet.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 历史复盘的详情（全屏高度 86% 的底部弹窗）。
Future<void> showReviewDetailSheet(
  BuildContext context, {
  required AiReview review,
}) {
  return showAppSheet<void>(
    context: context,
    barrierAlpha: 0.35,
    builder: (BuildContext _) => _ReviewDetailSheet(review: review),
  );
}

class _ReviewDetailSheet extends StatelessWidget {
  const _ReviewDetailSheet({required this.review});

  final AiReview review;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight = mq.size.height * 0.88;
    final AiReviewReport report =
        AiReviewReport.decode(review.content, model: review.model);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '${DayUtils.friendlyDate(review.date)}的复盘',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${review.provider} · ${review.model} · '
                              '${DayUtils.formatDateTime(review.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      BounceTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: c.inkFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (review.status == AiReviewStatus.failed)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: c.danger.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: c.danger.withValues(alpha: 0.26),
                          ),
                        ),
                        child: Text(
                          review.errorMessage.trim().isEmpty
                              ? '这条复盘没有生成成功。'
                              : review.errorMessage.trim(),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            color: c.danger,
                          ),
                        ),
                      ),
                    ReviewResultCard(
                      report: report,
                      createdAt: review.createdAt,
                    ),
                    const SizedBox(height: 6),
                    BounceTap(
                      onTap: () => showAiSnapshotSheet(
                        context,
                        json: review.snapshotJson,
                        subtitle: '${DayUtils.formatDate(review.date)} '
                            '发送给 ${review.provider} 的原始数据',
                      ),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.indigo.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: c.indigo.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.data_object_rounded,
                              size: 16,
                              color: c.indigo,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '查看这次发给模型的数据',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: c.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
