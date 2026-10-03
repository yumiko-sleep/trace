import 'package:flutter/material.dart';

import '../../../../core/utils/day_utils.dart';
import '../../domain/ai_review_report.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 复盘报告卡：一句话总结 + 四个分块。
///
/// 解析失败时（[AiReviewReport.parsed] == false）退化成原文展示，
/// 保证花了 token 的结果一定看得见。
class ReviewResultCard extends StatelessWidget {
  const ReviewResultCard({
    super.key,
    required this.report,
    this.createdAt,
    this.commitments = true,
  });

  final AiReviewReport report;
  final DateTime? createdAt;

  /// 是否显示「生成时间 / 模型」脚注。
  final bool commitments;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Headline(report: report, createdAt: createdAt, showMeta: commitments),
        const SizedBox(height: 14),
        if (!report.parsed)
          _RawTextBlock(text: report.rawText)
        else ...<Widget>[
          if (report.good.isNotEmpty)
            _Section(
              title: '今天做得好的',
              icon: Icons.thumb_up_rounded,
              color: c.mintDeep,
              items: report.good,
            ),
          if (report.improve.isNotEmpty)
            _Section(
              title: '需要改进的',
              icon: Icons.build_circle_rounded,
              color: c.amber,
              items: report.improve,
            ),
          if (report.tomorrow.isNotEmpty)
            _Section(
              title: '明天建议',
              icon: Icons.rocket_launch_rounded,
              color: c.sky,
              items: report.tomorrow,
              numbered: true,
            ),
          if (report.trendInsights.isNotEmpty)
            _Section(
              title: '数据趋势洞察',
              icon: Icons.insights_rounded,
              color: c.violet,
              items: report.trendInsights,
            ),
        ],
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.report,
    this.createdAt,
    required this.showMeta,
  });

  final AiReviewReport report;
  final DateTime? createdAt;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final String meta = <String>[
      if (createdAt != null) DayUtils.formatDateTime(createdAt!),
      if (report.model.isNotEmpty) report.model,
      if (report.itemCount > 0) '${report.itemCount} 条建议',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: c.review,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.violet.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 12),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(11),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.30)),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '今日复盘',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!report.parsed) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '原文展示',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (report.headline.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              report.headline.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.45,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
          if (showMeta && meta.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              meta,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.numbered = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    numbered
                        ? Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 8, left: 5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[i],
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.65,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RawTextBlock extends StatelessWidget {
  const _RawTextBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.text_snippet_rounded,
                size: 15,
                color: c.amber,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '模型没有按 JSON 格式返回，这里原样展示',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            text.trim().isEmpty ? '（模型返回了空内容）' : text.trim(),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: c.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
