import 'package:flutter/animation.dart';

/// 统一动效参数：时长与曲线。
///
/// 全项目只从这里取值，保证「丝滑」的一致性。
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);

  /// 底部弹窗的入场 / 出场时长。
  ///
  /// 全项目只在这里定义：所有 `showModalBottomSheet` 都吃
  /// [sheetStyle]（挂在 `ThemeData.bottomSheetTheme` 上），
  /// 所以不要在单个弹窗里另传 `sheetAnimationStyle`，否则就又不统一了。
  static const Duration sheet = Duration(milliseconds: 320);
  static const Duration sheetOut = Duration(milliseconds: 240);

  /// 板块 / 页面切换。
  static const Duration page = Duration(milliseconds: 380);

  /// 进场错峰间隔。
  static const Duration stagger = Duration(milliseconds: 70);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve softInOut = Curves.easeInOutCubic;

  /// 轻微回弹，用于按压反馈。
  static const Curve spring = Curves.easeOutBack;

  /// 底部弹窗统一的动画时长（给 `BottomSheetThemeData.sheetAnimationStyle` 用）。
  static const AnimationStyle sheetStyle = AnimationStyle(
    duration: sheet,
    reverseDuration: sheetOut,
  );
}
