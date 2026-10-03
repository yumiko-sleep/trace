import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_review/presentation/ai_review_page.dart';
import '../../features/diary/presentation/diary_editor_page.dart';
import '../../features/diary/presentation/diary_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/journal/presentation/journal_page.dart';
import '../../features/metrics/presentation/metrics_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/tasks/presentation/tasks_page.dart';

/// 统一维护路由路径，避免到处写字符串。
class AppRoutes {
  const AppRoutes._();

  // 底部导航（Shell 内）
  static const String home = '/home';
  static const String review = '/review';
  static const String settings = '/settings';

  // 五大板块（全屏页面）
  static const String tasks = '/tasks';
  static const String goals = '/goals';
  static const String diary = '/diary';
  static const String diaryEditor = '/diary/edit';
  static const String metrics = '/metrics';
  static const String journal = '/journal';
}

/// 创建一个全新的路由实例。
///
/// 这里刻意用「工厂函数」而不是全局单例：
/// 每次 App 挂载都拿到干净的路由状态，Widget 测试之间也不会互相串味。
GoRouter createAppRouter() {
  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      // 底部导航外壳：首页 / 复盘 / 设置
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
                StatefulNavigationShell navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.review,
                builder: (_, __) => const AiReviewPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, __) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),

      // 五大板块：挂在根导航器上，全屏展示并隐藏底部导航
      GoRoute(
        path: AppRoutes.tasks,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const TasksPage(),
      ),
      GoRoute(
        path: AppRoutes.goals,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const GoalsPage(),
      ),
      GoRoute(
        path: AppRoutes.diary,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const DiaryPage(),
      ),
      // 日记编辑页（全屏）：日期通过 extra 传入
      GoRoute(
        path: AppRoutes.diaryEditor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, GoRouterState state) {
          final Object? extra = state.extra;
          return DiaryEditorPage(
            date: extra is DateTime ? extra : DateTime.now(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.metrics,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const MetricsPage(),
      ),
      GoRoute(
        path: AppRoutes.journal,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const JournalPage(),
      ),
    ],
  );
}
