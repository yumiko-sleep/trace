// CupertinoPageTransitionsBuilder 在 Flutter 3.27+ 已不再由 material.dart 转导出，
// 需要单独从 cupertino.dart 引入（用前缀避免命名冲突）。
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_scheme.dart';
import 'app_typography.dart';

/// 把当前 [AppScheme] 挂到 ThemeData 上，供 `context.scheme` 取用。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette(this.scheme);

  final AppScheme scheme;

  @override
  AppPalette copyWith({AppScheme? scheme}) =>
      AppPalette(scheme ?? this.scheme);

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    // 配色切换不做插值：整体换肤比逐色渐变好看，也不会出现中间态串色
    if (other is AppPalette) {
      return t < 0.5 ? this : other;
    }
    return this;
  }
}

/// 取配色的便捷入口：`final AppScheme c = context.scheme;`
extension AppSchemeContext on BuildContext {
  AppScheme get scheme =>
      Theme.of(this).extension<AppPalette>()?.scheme ?? AppScheme.mintLight;
}

/// 应用主题。Material 3 + 全局透明 Scaffold（背景由 GradientBackground 负责绘制）。
class AppTheme {
  const AppTheme._();

  /// 依据配色方案生成 ThemeData（浅色与深色走同一套逻辑）。
  static ThemeData build(AppScheme s) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: s.mint,
      brightness: s.brightness,
    ).copyWith(
      primary: s.mint,
      secondary: s.cyan,
      tertiary: s.sky,
      surface: s.surface,
      onSurface: s.ink,
      error: s.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: s.brightness,
      colorScheme: scheme,
      textTheme: AppTypography.of(s),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: s.surface,
      dividerColor: s.line,
      splashColor: s.mint.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      fontFamily: null,
      dialogTheme: DialogThemeData(backgroundColor: s.surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: s.isDark ? s.surface : null,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: s.ink,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // 深色主题下状态栏图标要反过来，否则看不清
          statusBarIconBrightness:
              s.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              s.isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          // Android：Material 3 新版「淡入前移」转场（原生、丝滑）
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          // iOS / macOS：系统横向滑动转场
          TargetPlatform.iOS: cupertino.CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: cupertino.CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[AppPalette(s)],
    );
  }

  /// 默认（薄荷绿蓝 · 跟随系统）——给测试与兜底场景用。
  static ThemeData get light => build(AppScheme.mintLight);

  static ThemeData get dark => build(AppScheme.mintDark);
}
