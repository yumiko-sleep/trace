import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/gradient_background.dart';
import 'widgets/glass_nav_bar.dart';

/// 底部导航外壳：承载「首页 / 复盘 / 设置」三个分支。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      // 给内容区留出底部导航条的高度：这样页面内的悬浮按钮不会藏在导航条下面，
      // 滚动到底时最后一项也不会被玻璃条盖住。
      body: GradientBackground(
        child: Padding(
          padding: EdgeInsets.only(bottom: 12 + bottomInset + 64),
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: 12 + bottomInset,
        ),
        child: GlassNavBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
        ),
      ),
    );
  }
}
