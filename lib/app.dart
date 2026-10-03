import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_scheme.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/theme_providers.dart';

class TraceApp extends ConsumerStatefulWidget {
  const TraceApp({super.key});

  @override
  ConsumerState<TraceApp> createState() => _TraceAppState();
}

class _TraceAppState extends ConsumerState<TraceApp> {
  /// 每个 App 实例持有自己的路由实例：
  /// 既避免全局状态在多次挂载之间串味，也让单元测试彼此隔离。
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外观设置从数据库读取；读完之前先用兜底（跟随系统 + 默认配色）
    final AppThemeSettings settings =
        ref.watch(appThemeSettingsProvider).valueOrNull ??
            AppThemeSettings.fallback;

    return MaterialApp.router(
      title: '轨迹 Trace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(settings.family.light),
      darkTheme: AppTheme.build(settings.family.dark),
      themeMode: settings.mode,
      routerConfig: _router,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        // 锁定文字缩放上限，避免系统字体过大破坏渐变卡片的排版。
        final MediaQueryData mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
