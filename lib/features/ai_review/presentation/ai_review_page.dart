import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/day_utils.dart';
import '../../../core/widgets/bounce_tap.dart';
import '../../../core/widgets/diary_media.dart' show PillActionButton;
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/section_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/services/ai/ai_config.dart';
import '../domain/ai_review_report.dart';
import '../providers/ai_review_providers.dart';
import 'widgets/ai_status_cards.dart';
import 'widgets/review_detail_sheet.dart';
import 'widgets/review_history_card.dart';
import 'widgets/review_result_card.dart';
import 'widgets/snapshot_sheet.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// AI 每日复盘。
class AiReviewPage extends ConsumerStatefulWidget {
  const AiReviewPage({super.key});

  @override
  ConsumerState<AiReviewPage> createState() => _AiReviewPageState();
}

class _AiReviewPageState extends ConsumerState<AiReviewPage> {
  @override
  void initState() {
    super.initState();
    // 进页时把「卡住的」pending 记录标成失败（App 被杀 / 请求中断留下的），
    // 否则界面会一直显示「生成中」。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiReviewControllerProvider.notifier).cleanStalePending();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final AsyncValue<AiConfig> asyncConfig = ref.watch(aiConfigProvider);
    final AiReviewRunState run = ref.watch(aiReviewControllerProvider);
    final AsyncValue<AiReview?> asyncToday = ref.watch(todayAiReviewProvider);
    final List<AiReview> history =
        ref.watch(aiReviewHistoryProvider).valueOrNull ?? const <AiReview>[];

    final AiReview? today = asyncToday.valueOrNull;
    final AiReviewReport? todayReport =
        today != null && today.content.trim().isNotEmpty
            ? AiReviewReport.decode(today.content, model: today.model)
            : null;

    final bool running = run.running || today?.status == AiReviewStatus.pending;
    final String todayDate = DayUtils.friendlyDate(DateTime.now());

    Future<void> generate() =>
        ref.read(aiReviewControllerProvider.notifier).generate();

    void cancel() => ref.read(aiReviewControllerProvider.notifier).cancel();

    return SectionScaffold(
      showBack: false,
      title: 'AI 每日复盘',
      subtitle: '让模型读懂你的一天，给出明天能做的三件事',
      icon: Icons.auto_awesome_rounded,
      gradient: c.review,
      bottomPadding: 132,
      floatingActionButton: PillActionButton(
        label: running ? '生成中…' : '生成今天的复盘',
        icon: running
            ? Icons.hourglass_top_rounded
            : Icons.auto_awesome_rounded,
        gradient: c.review,
        shadowColor: c.violet,
        onTap: running ? () {} : generate,
      ),
      children: <Widget>[
        AiConfigCard(
          loading: asyncConfig.isLoading,
          config: asyncConfig.valueOrNull,
          onOpenSettings: () => context.go(AppRoutes.settings),
        ),
        const SizedBox(height: 16),

        // ---------- 运行中 ----------
        if (run.running) ...<Widget>[
          AiRunningCard(step: run.step, onCancel: cancel),
          const SizedBox(height: 16),
        ],

        // ---------- 本地错误 ----------
        if (run.error != null) ...<Widget>[
          AiErrorCard(
            message: run.error!,
            onRetry: generate,
            onDismiss: () =>
                ref.read(aiReviewControllerProvider.notifier).clearError(),
          ),
          const SizedBox(height: 16),
        ],

        SectionHeader(
          title: '今天的复盘',
          subtitle: running
              ? '正在生成，通常十几秒'
              : (todayReport != null
                  ? '已生成 · $todayDate'
                  : '$todayDate 还没有生成'),
        ),
        const SizedBox(height: 12),

        if (running && todayReport == null && run.error == null)
          const _PendingHint()        else if (today?.status == AiReviewStatus.failed)
          AiErrorCard(
            message: today!.errorMessage.trim().isEmpty
                ? '这次生成失败了。'
                : today.errorMessage.trim(),
            onRetry: generate,
          )
        else if (todayReport != null) ...<Widget>[
          ReviewResultCard(report: todayReport, createdAt: today!.createdAt),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _OutlineButton(
                  label: '查看发给模型的数据',
                  icon: Icons.data_object_rounded,
                  color: c.indigo,
                  onTap: () => showAiSnapshotSheet(
                    context,
                    json: today.snapshotJson,
                    subtitle: '${DayUtils.formatDate(today.date)} '
                        '发送给 ${today.provider} 的原始数据',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlineButton(
                  label: '重新生成',
                  icon: Icons.refresh_rounded,
                  color: c.violet,
                  onTap: generate,
                ),
              ),
            ],
          ),
        ] else
          _EmptyTodayCard(onGenerate: generate),

        const SizedBox(height: 26),
        SectionHeader(
          title: '历史复盘',
          subtitle: history.isEmpty
              ? '还没有生成过'
              : '共 ${history.length} 条 · 点一条看全文，左滑删除',
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            child: Column(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.violet.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: c.violet,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '还没有复盘记录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '先把今天的数据填一填（任务、日记、数据、日志），\n'
                  '生成出来的复盘才会具体。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          )
        else
          for (final AiReview review in history.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReviewHistoryCard(
                review: review,
                headline: review.content.trim().isEmpty
                    ? ''
                    : AiReviewReport.decode(
                        review.content,
                        model: review.model,
                      ).headline,
                onTap: () => showReviewDetailSheet(context, review: review),
                onDelete: () => _deleteReview(context, ref, review),
              ),
            ),

        const SizedBox(height: 16),
        const InfoNote(
          icon: Icons.lock_outline_rounded,
          text: '隐私说明：所有数据默认只存在本机。只有你手动点击生成时，'
              '才会把当天数据（任务 / 目标 / 日记文字 / 数据趋势 / 日志）打包成 JSON '
              '发给你选择的服务商；API Key 存在系统安全存储里，不会写进代码仓库。'
              '当前版本只发送文字，日记图片仅统计数量，不上传图片。',
        ),
      ],
    );
  }

  /// 删除 + 撤销提示条。
  Future<void> _deleteReview(
    BuildContext context,
    WidgetRef ref,
    AiReview review,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(aiReviewControllerProvider.notifier).remove(review);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除 ${DayUtils.friendlyDate(review.date)} 的复盘'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () =>
                ref.read(aiReviewControllerProvider.notifier).restore(review),
          ),
        ),
      );
  }
}

/// 生成中、还没有结果的占位。
class _PendingHint extends StatelessWidget {
  const _PendingHint();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '模型正在分析今天的任务、目标、日记、数据趋势与日志…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// 今天还没生成时的引导卡。
class _EmptyTodayCard extends StatelessWidget {
  const _EmptyTodayCard({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '一次复盘会读这些数据',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 12),
          for (final List<Object> row in const <List<Object>>[
            <Object>[Icons.task_alt_rounded, '任务完成情况（含顺延未完成的）'],
            <Object>[Icons.flag_rounded, '目标的进度与剩余时间'],
            <Object>[Icons.auto_stories_rounded, '当天日记文字与心情'],
            <Object>[Icons.query_stats_rounded, '数据项最近 7 天的数字表格'],
            <Object>[Icons.menu_book_rounded, '学习 / 训练日志与你的自我复盘'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    row[0] as IconData,
                    size: 15,
                    color: c.violet,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row[1] as String,
                      style: TextStyle(
                        fontSize: 12.8,
                        height: 1.5,
                        color: c.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          BounceTap(
            onTap: onGenerate,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: c.review,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.violet.withValues(alpha: 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '生成今天的复盘',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 输出型小按钮（描边胶囊）。
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
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
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
