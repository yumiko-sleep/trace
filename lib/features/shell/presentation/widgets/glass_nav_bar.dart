import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

class NavItemData {
  const NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 玻璃拟态底部导航条：选中项展开为渐变胶囊（图标 + 文字），未选中仅显示图标。
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<NavItemData> items = <NavItemData>[
    NavItemData(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: '首页',
    ),
    NavItemData(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      label: '复盘',
    ),
    NavItemData(
      icon: Icons.tune_rounded,
      activeIcon: Icons.tune_rounded,
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.ink.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
            ),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) _buildItem(context, i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final AppScheme c = context.scheme;
    final bool selected = index == currentIndex;
    final NavItemData item = items[index];

    return Expanded(
      child: BounceTap(
        onTap: () => onTap(index),
        scale: 0.93,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 16 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: selected ? c.primary : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: c.cyan.withValues(alpha: 0.34),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                        spreadRadius: -3,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 21,
                  color: selected ? Colors.white : c.inkFaint,
                ),
                AnimatedSize(
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
