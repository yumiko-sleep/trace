import 'package:flutter/material.dart';

/// ============================================================
/// 配色方案（两套品牌色系 × 浅色 / 深色 = 4 种组合）
///
/// 使用方式：在 Widget 里 `final AppScheme c = context.scheme;`，
/// 然后把颜色一律写成 `c.ink` / `c.card` / `c.tasks`（渐变）。
/// 不要直接写 `Colors.white` 之类的字面色（渐变头部的白色叠层除外）。
///
/// 关于字段名：`mint / cyan / sky / indigo / violet` 是两套方案**共用的槽位名**，
/// 名字来源于默认方案「薄荷绿蓝」的色相；在「樱花粉白」方案里它们承载粉紫色相。
/// ============================================================

/// 品牌色系（用户可选的两套配色）。
enum AppColorFamily {
  /// 薄荷绿蓝（默认）
  mint,

  /// 樱花粉白
  sakura,
}

extension AppColorFamilyX on AppColorFamily {
  String get id => name;

  String get label => switch (this) {
        AppColorFamily.mint => '薄荷绿蓝',
        AppColorFamily.sakura => '樱花粉白',
      };

  String get description => switch (this) {
        AppColorFamily.mint => '干净、冷静，看久了不累',
        AppColorFamily.sakura => '温柔、明亮，带一点甜',
      };

  AppScheme get light => switch (this) {
        AppColorFamily.mint => AppScheme.mintLight,
        AppColorFamily.sakura => AppScheme.sakuraLight,
      };

  AppScheme get dark => switch (this) {
        AppColorFamily.mint => AppScheme.mintDark,
        AppColorFamily.sakura => AppScheme.sakuraDark,
      };

  AppScheme of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// 设置页配色选项上的预览色带
  List<Color> get previewGradient => light.header.colors;
}

AppColorFamily appColorFamilyFromId(String id) => AppColorFamily.values.firstWhere(
      (AppColorFamily f) => f.id == id,
      orElse: () => AppColorFamily.mint,
    );

/// 一套完整的配色。
@immutable
class AppScheme {
  const AppScheme({
    required this.family,
    required this.brightness,
    required this.mint,
    required this.cyan,
    required this.sky,
    required this.indigo,
    required this.violet,
    required this.mintDeep,
    required this.danger,
    required this.amber,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.surface,
    required this.card,
    required this.bgTop,
    required this.bgBottom,
    required this.primary,
    required this.header,
    required this.tasks,
    required this.goals,
    required this.diary,
    required this.metrics,
    required this.journal,
    required this.review,
    required this.disabled,
  });

  final AppColorFamily family;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // ---------- 品牌色（槽位名见文件顶部说明）----------
  final Color mint;
  final Color cyan;
  final Color sky;
  final Color indigo;
  final Color violet;

  /// 主色的「深/亮」版本：用于浅底上的强调文字与达标、成功等语义。
  final Color mintDeep;

  final Color danger;
  final Color amber;

  // ---------- 中性色 ----------
  /// 主要文字
  final Color ink;

  /// 次要文字
  final Color inkSoft;

  /// 弱化文字 / 占位
  final Color inkFaint;

  /// 描边
  final Color line;

  /// 实心面板色（对话框等）
  final Color surface;

  /// 卡片底色（已经带好透明度）
  final Color card;

  final Color bgTop;
  final Color bgBottom;

  // ---------- 渐变 ----------
  final LinearGradient primary;
  final LinearGradient header;
  final LinearGradient tasks;
  final LinearGradient goals;
  final LinearGradient diary;
  final LinearGradient metrics;
  final LinearGradient journal;
  final LinearGradient review;
  final LinearGradient disabled;

  /// 页面背景（自上而下极浅/极深的过渡）
  LinearGradient get page => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[bgTop, bgBottom],
      );

  /// 卡片上的柔和阴影色
  Color get shadow => ink.withValues(alpha: isDark ? 0.22 : 0.05);

  /// 大面积渐变块下方那层彩色投影
  Color glow(Color color) => color.withValues(alpha: isDark ? 0.26 : 0.32);

  String get id => '${family.id}_${isDark ? 'dark' : 'light'}';

  String get label => '${family.label} · ${isDark ? '深色' : '浅色'}';

  // ============================================================
  // 四套具体配色
  // ============================================================

  /// 薄荷绿蓝 · 浅色（默认，第一版沿用至今的配色）
  static const AppScheme mintLight = AppScheme(
    family: AppColorFamily.mint,
    brightness: Brightness.light,
    mint: Color(0xFF3DDC97),
    cyan: Color(0xFF22C1DC),
    sky: Color(0xFF2E9BF7),
    indigo: Color(0xFF5B7CFA),
    violet: Color(0xFF8B6CF7),
    mintDeep: Color(0xFF17A87A),
    danger: Color(0xFFF26D6D),
    amber: Color(0xFFF2A93B),
    ink: Color(0xFF10233A),
    inkSoft: Color(0xFF4A617A),
    inkFaint: Color(0xFF93A6B8),
    line: Color(0xFFE6EFF7),
    surface: Color(0xFFFFFFFF),
    card: Color(0xF0FFFFFF),
    bgTop: Color(0xFFF7FCFE),
    bgBottom: Color(0xFFECF3FF),
    primary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3DDC97), Color(0xFF22C1DC)],
    ),
    header: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3DDC97), Color(0xFF22C1DC), Color(0xFF2E9BF7)],
    ),
    tasks: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3DDC97), Color(0xFF22C1DC)],
    ),
    goals: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF1FC4D8), Color(0xFF2E9BF7)],
    ),
    diary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2E9BF7), Color(0xFF5B7CFA)],
    ),
    metrics: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF5B7CFA), Color(0xFF8B6CF7)],
    ),
    journal: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF8B6CF7), Color(0xFFA98BFA)],
    ),
    review: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF6C7BF7), Color(0xFFA98BFA)],
    ),
    disabled: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFC7D3DE), Color(0xFFB9C7D4)],
    ),
  );

  /// 薄荷绿蓝 · 深色
  static const AppScheme mintDark = AppScheme(
    family: AppColorFamily.mint,
    brightness: Brightness.dark,
    mint: Color(0xFF4CE0A2),
    cyan: Color(0xFF3ED2E8),
    sky: Color(0xFF58A9F9),
    indigo: Color(0xFF8095FF),
    violet: Color(0xFFA98BFA),
    mintDeep: Color(0xFF5FE6AD),
    danger: Color(0xFFF98A8A),
    amber: Color(0xFFF5B85F),
    ink: Color(0xFFE7EEF5),
    inkSoft: Color(0xFFA9BCCE),
    inkFaint: Color(0xFF6F8598),
    line: Color(0xFF27323E),
    surface: Color(0xFF141C24),
    card: Color(0xF01A232D),
    bgTop: Color(0xFF0D131A),
    bgBottom: Color(0xFF121B25),
    primary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3DDC97), Color(0xFF22C1DC)],
    ),
    header: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2BBE85), Color(0xFF1FA5BE), Color(0xFF2A7FD6)],
    ),
    tasks: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2BBE85), Color(0xFF1FA5BE)],
    ),
    goals: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF1AA6B8), Color(0xFF2A7FD6)],
    ),
    diary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2A7FD6), Color(0xFF4B67DB)],
    ),
    metrics: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF4B67DB), Color(0xFF7357DE)],
    ),
    journal: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF7357DE), Color(0xFF8F73E6)],
    ),
    review: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF5566DE), Color(0xFF8F73E6)],
    ),
    disabled: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2A3743), Color(0xFF24303B)],
    ),
  );

  /// 樱花粉白 · 浅色
  static const AppScheme sakuraLight = AppScheme(
    family: AppColorFamily.sakura,
    brightness: Brightness.light,
    mint: Color(0xFFFF8FB8),
    cyan: Color(0xFFFFB3D1),
    sky: Color(0xFFF0699B),
    indigo: Color(0xFFC77DD6),
    violet: Color(0xFFB389E8),
    mintDeep: Color(0xFFD6437F),
    danger: Color(0xFFF26D6D),
    amber: Color(0xFFF2A93B),
    ink: Color(0xFF33222C),
    inkSoft: Color(0xFF6E5661),
    inkFaint: Color(0xFFA79099),
    line: Color(0xFFF7E3EC),
    surface: Color(0xFFFFFFFF),
    card: Color(0xF0FFFFFF),
    bgTop: Color(0xFFFFF9FC),
    bgBottom: Color(0xFFFFEDF4),
    primary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFF8FB8), Color(0xFFFFB0CE)],
    ),
    header: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFF8FB8), Color(0xFFFFA6C9), Color(0xFFCF8BE4)],
    ),
    tasks: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFF8FB8), Color(0xFFFFA9CD)],
    ),
    goals: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF0699B), Color(0xFFFF93BE)],
    ),
    diary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFF8FB8), Color(0xFFC77DD6)],
    ),
    metrics: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFC77DD6), Color(0xFFB389E8)],
    ),
    journal: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFB389E8), Color(0xFFE0A2DC)],
    ),
    review: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFD96BB0), Color(0xFFB389E8)],
    ),
    disabled: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFEBD5DE), Color(0xFFE0C7D3)],
    ),
  );

  /// 樱花粉白 · 深色
  static const AppScheme sakuraDark = AppScheme(
    family: AppColorFamily.sakura,
    brightness: Brightness.dark,
    mint: Color(0xFFFFA3C6),
    cyan: Color(0xFFFFC2DA),
    sky: Color(0xFFFF7FAE),
    indigo: Color(0xFFD89BE4),
    violet: Color(0xFFC39BF0),
    mintDeep: Color(0xFFFF9EC4),
    danger: Color(0xFFF98A8A),
    amber: Color(0xFFF5B85F),
    ink: Color(0xFFF5EDF1),
    inkSoft: Color(0xFFC6B2BC),
    inkFaint: Color(0xFF8E7A85),
    line: Color(0xFF33262F),
    surface: Color(0xFF1C141C),
    card: Color(0xF0211A21),
    bgTop: Color(0xFF140F14),
    bgBottom: Color(0xFF1D151D),
    primary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFE86E9E), Color(0xFFF090B8)],
    ),
    header: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFD95E92), Color(0xFFE07FAE), Color(0xFFA868C6)],
    ),
    tasks: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFE86E9E), Color(0xFFF090B8)],
    ),
    goals: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFCF4F86), Color(0xFFE86E9E)],
    ),
    diary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFE86E9E), Color(0xFFA868C6)],
    ),
    metrics: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFA868C6), Color(0xFF9A72D8)],
    ),
    journal: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF9A72D8), Color(0xFFC77FC0)],
    ),
    review: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFB85A9A), Color(0xFF9A72D8)],
    ),
    disabled: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3A2C36), Color(0xFF322630)],
    ),
  );

  /// 四套配色（设置页预览与测试用）
  static const List<AppScheme> all = <AppScheme>[
    mintLight,
    mintDark,
    sakuraLight,
    sakuraDark,
  ];

  /// 依据系列与亮度取一套。
  static AppScheme resolve(AppColorFamily family, Brightness brightness) =>
      brightness == Brightness.dark ? family.dark : family.light;

  AppScheme withBrightness(Brightness b) => resolve(family, b);
}
