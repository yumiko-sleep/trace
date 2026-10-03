import 'package:flutter/animation.dart';

/// 统一动效参数：时长与曲线。
///
/// 全项目只从这里取值，保证「丝滑」的一致性。
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);

  /// 板块 / 页面切换。
  static const Duration page = Duration(milliseconds: 380);

  /// 进场错峰间隔。
  static const Duration stagger = Duration(milliseconds: 70);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve softInOut = Curves.easeInOutCubic;

  /// 轻微回弹，用于按压反馈。
  static const Curve spring = Curves.easeOutBack;
}
