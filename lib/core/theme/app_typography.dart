import 'package:flutter/material.dart';

import 'app_scheme.dart';

/// 统一字体样式（使用系统默认字体，中文显示更自然，也避免首次启动联网下载字体）。
///
/// 颜色全部来自当前 [AppScheme]，所以深色 / 换配色时文字会跟着变。
class AppTypography {
  const AppTypography._();

  static TextTheme of(AppScheme s) => TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          height: 1.18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: s.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          height: 1.22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: s.ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: s.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: s.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: s.ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: s.inkSoft,
        ),
        bodyMedium: TextStyle(
          fontSize: 13.5,
          height: 1.55,
          fontWeight: FontWeight.w400,
          color: s.inkSoft,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: s.inkFaint,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: s.ink,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: s.inkFaint,
        ),
      );
}
