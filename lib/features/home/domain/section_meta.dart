import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scheme.dart';

/// 五大板块的静态元数据：标题、副标题、图标、路由。
class AppSection {
  const AppSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  /// 从当前配色方案里取本板块的渐变。
  LinearGradient gradientOf(AppScheme s) => switch (id) {        'tasks' => s.tasks,
        'goals' => s.goals,
        'diary' => s.diary,
        'metrics' => s.metrics,
        _ => s.journal,
      };
}

const List<AppSection> kAppSections = <AppSection>[
  AppSection(
    id: 'tasks',
    title: '今日任务',
    subtitle: '把今天要做的事一件件勾掉',
    icon: Icons.task_alt_rounded,
    route: AppRoutes.tasks,
  ),
  AppSection(
    id: 'goals',
    title: '目标',
    subtitle: '今日 · 今年 · 人生',
    icon: Icons.flag_rounded,
    route: AppRoutes.goals,
  ),
  AppSection(
    id: 'diary',
    title: '日记',
    subtitle: '文字 · 图片 · 心情',
    icon: Icons.auto_stories_rounded,
    route: AppRoutes.diary,
  ),
  AppSection(
    id: 'metrics',
    title: '数据',
    subtitle: '睡眠 · 运动 · 阅读趋势',
    icon: Icons.query_stats_rounded,
    route: AppRoutes.metrics,
  ),
  AppSection(
    id: 'journal',
    title: '日志',
    subtitle: '学习 · 训练 · 每日复盘',
    icon: Icons.menu_book_rounded,
    route: AppRoutes.journal,
  ),
];
