import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/day_utils.dart';
import '../../../core/widgets/bounce_tap.dart';
import '../../../core/widgets/diary_media.dart' show PillActionButton;
import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/section_scaffold.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../domain/journal_stats.dart';
import '../providers/journal_providers.dart';
import 'widgets/journal_log_card.dart';
import 'widgets/journal_log_sheet.dart';
import 'widgets/journal_plan_card.dart';
import 'widgets/journal_plan_sheet.dart';
import 'widgets/journal_review_sheet.dart';
import 'widgets/journal_summary_card.dart';
import 'widgets/journal_type_selector.dart';
import 'widgets/journal_visuals.dart';
import 'widgets/today_journal_card.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// 板块 5：日志（学习日志 + 训练日志 + 每日复盘）。
class JournalPage extends ConsumerWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScheme c = context.scheme;
    final JournalType type = ref.watch(journalTypeProvider);
    final AsyncValue<List<JournalPlan>> asyncPlans =
        ref.watch(journalPlansProvider);
    final List<JournalPlan> plans =
        asyncPlans.valueOrNull ?? const <JournalPlan>[];
    final AsyncValue<List<JournalLog>> asyncLogs = ref.watch(journalLogsProvider);
    final List<JournalLog> logs =
        asyncLogs.valueOrNull ?? const <JournalLog>[];
    final JournalLog? todayLog = ref.watch(journalTodayLogProvider);
    final JournalStats stats = ref.watch(journalStatsProvider);
    final Map<int, String> planTitles = ref.watch(journalPlanTitlesProvider);
    final bool loading = (asyncLogs.isLoading && !asyncLogs.hasValue) ||
        (asyncPlans.isLoading && !asyncPlans.hasValue);

    final Color color = journalColor(type);
    final DateTime today = DateTime.now();

    void openLogSheet({JournalLog? log}) => showJournalLogSheet(
          context,
          type: type,
          date: log?.date ?? today,
          log: log,
        );

    return SectionScaffold(
      title: '日志',
      subtitle: '计划在前，记录在后，复盘收尾。',
      icon: Icons.menu_book_rounded,
      gradient: c.journal,
      bottomPadding: 120,
      floatingActionButton: PillActionButton(
        label: '记录今天',
        icon: Icons.edit_calendar_rounded,
        gradient: journalGradient(type, c),
        shadowColor: color,
        onTap: () => openLogSheet(log: todayLog),
      ),
      children: <Widget>[
        JournalTypeSelector(
          value: type,
          onChanged: (JournalType t) =>
              ref.read(journalTypeProvider.notifier).state = t,
        ),
        const SizedBox(height: 18),
        JournalSummaryCard(
          type: type,
          stats: stats,
          todayLogged: todayLog != null,
          onRecord: () => openLogSheet(log: todayLog),
        ),
        const SizedBox(height: 20),
        TodayJournalCard(
          type: type,
          log: todayLog,
          planTitle: todayLog?.planId == null
              ? null
              : planTitles[todayLog!.planId!],
          onRecord: () => openLogSheet(log: todayLog),
          onReview: () => showJournalReviewSheet(
            context,
            type: type,
            date: today,
            initialReview: todayLog?.review ?? '',
          ),
        ),
        const SizedBox(height: 26),
        SectionHeader(
          title: type.planTitle,
          subtitle: plans.isEmpty
              ? '还没有计划，先定个方向'
              : '共 ${plans.length} 个 · 点一下编辑，左滑删除',
          trailing: _AddPlanButton(
            label: '新建计划',
            color: color,
            onTap: () => showJournalPlanSheet(context, type: type),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else ...<Widget>[
          if (plans.isEmpty)
            JournalEmptyHint(
              icon: Icons.checklist_rounded,
              color: color,
              title: '还没有${type.planTitle}',
              description: type == JournalType.study
                  ? '先写一个学习计划（比如「数学一轮复习」），每天记录时就能关联到它，'
                      '回头看才知道进度走到哪了。'
                  : '先写一个训练计划（比如「推 / 拉 / 腿 三分化」），每天记录时就能关联到它，'
                      '下次加多少重量也有据可依。',
              actionLabel: '新建计划',
              onAction: () => showJournalPlanSheet(context, type: type),
            )
          else
            for (final JournalPlan plan in plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: JournalPlanCard(
                  plan: plan,
                  onTap: () =>
                      showJournalPlanSheet(context, type: type, plan: plan),
                  onDelete: () => _deletePlan(context, ref, plan),
                ),
              ),
          const SizedBox(height: 18),
          SectionHeader(
            title: '历史记录',
            subtitle: logs.isEmpty
                ? '还没有记录'
                : '共 ${logs.length} 条 · 点一条可以编辑',
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            JournalEmptyHint(
              icon: type == JournalType.study
                  ? Icons.auto_stories_rounded
                  : Icons.directions_run_rounded,
              color: color,
              title: '还没有${type.shortLabel}记录',
              description: '每天花一分钟写下「今天做了什么 + 花了多久」，'
                  '再补一句复盘。坚持一周，回头看会很不一样。',
              actionLabel: '记录今天',
              onAction: () => openLogSheet(),
            )
          else
            for (final JournalLog log in logs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: JournalLogCard(
                  log: log,
                  planTitle:
                      log.planId == null ? null : planTitles[log.planId!],
                  onTap: () => openLogSheet(log: log),
                  onDelete: () => _deleteLog(context, ref, log),
                ),
              ),
        ],
        const SizedBox(height: 16),
        const InfoNote(
          text: '日志分两层：计划是长期方向，记录是每天实际做了什么，复盘是回头看哪一步没走对。'
              '三者都会作为上下文进入阶段 7 的 AI 复盘。',
        ),
      ],
    );
  }

  /// 删除记录 + 撤销提示条。
  Future<void> _deleteLog(
    BuildContext context,
    WidgetRef ref,
    JournalLog log,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(journalActionsProvider).removeLog(log);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除 ${DayUtils.friendlyDate(log.date)} 的记录'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => ref.read(journalActionsProvider).restoreLog(log),
          ),
        ),
      );
  }

  /// 删除计划 + 撤销提示条（历史记录会保留，只是解绑）。
  Future<void> _deletePlan(
    BuildContext context,
    WidgetRef ref,
    JournalPlan plan,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(journalActionsProvider).removePlan(plan);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除计划「${plan.title}」'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => ref.read(journalActionsProvider).restorePlan(plan),
          ),
        ),
      );
  }
}

/// 小号的「新建计划」胶囊按钮（放在小节标题右侧）。
class _AddPlanButton extends StatelessWidget {
  const _AddPlanButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BounceTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
