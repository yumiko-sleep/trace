import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../../goals/providers/goal_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../domain/section_meta.dart';
import 'widgets/greeting_header.dart';
import 'widgets/overview_hero_card.dart';
import 'widgets/section_tile.dart';

/// 主页：问候 + 今日概览（真实数据）+ 五大板块入口。
///
/// 背景由 AppShell 提供，页面本身保持透明。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const List<AppSection> sections = kAppSections;

    // ---- 今日概览的真实数据 ----
    final DayTaskStats taskStats = ref.watch(taskStatsProvider);
    final List<Goal> goals =
        ref.watch(allGoalsProvider).valueOrNull ?? const <Goal>[];
    final int goalActive =
        goals.where((Goal g) => g.status == GoalStatus.active).length;
    final int goalDone =
        goals.where((Goal g) => g.status == GoalStatus.done).length;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const FadeSlideIn(index: 0, child: GreetingHeader()),
            const SizedBox(height: 20),
            FadeSlideIn(
              index: 1,
              child: OverviewHeroCard(
                taskDone: taskStats.done,
                taskTotal: taskStats.total,
                goalActive: goalActive,
                goalDone: goalDone,
              ),
            ),
            const SizedBox(height: 26),
            const FadeSlideIn(
              index: 2,
              child: SectionHeader(
                title: '五大板块',
                subtitle: '从任意一个入口开始记录',
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 3,
              child: Row(
                children: <Widget>[
                  Expanded(child: SectionTile(section: sections[0])),
                  const SizedBox(width: 14),
                  Expanded(child: SectionTile(section: sections[1])),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 4,
              child: Row(
                children: <Widget>[
                  Expanded(child: SectionTile(section: sections[2])),
                  const SizedBox(width: 14),
                  Expanded(child: SectionTile(section: sections[3])),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 5,
              child: SectionTile(section: sections[4], wide: true),
            ),
            const SizedBox(height: 26),
            const FadeSlideIn(index: 6, child: _FooterNote()),
          ],
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '轨迹 Trace · 完全开源 · 所有数据只存在你的手机上',
        style: TextStyle(
          fontSize: 11,
          color: context.scheme.inkFaint.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
