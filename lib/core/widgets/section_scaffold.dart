import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_scheme.dart';
import '../theme/app_theme.dart';
import 'bounce_tap.dart';
import 'fade_slide_in.dart';
import 'gradient_background.dart';

/// 板块页面统一骨架：顶部渐变大标题 + 可滚动内容。
///
/// 五大板块页面（全屏、带返回）与 Shell 内页面（复盘 / 设置）共用此骨架。
/// 内容块会依次错峰淡入（见 [FadeSlideIn]）。
class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.children = const <Widget>[],
    this.showBack = true,
    this.floatingActionButton,
    this.bottomPadding = 48,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final List<Widget> children;
  final bool showBack;

  /// 右下角悬浮按钮（可选）。
  final Widget? floatingActionButton;

  /// 内容区底部留白，避免最后一项被悬浮按钮遮住。
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: GradientBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(
                title: title,
                subtitle: subtitle,
                icon: icon,
                gradient: gradient,
                topPadding: topPadding,
                showBack: showBack,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 错峰入场：让内容依次浮上来，而不是一整块瞬间出现。
                    // 只给前几项递增延迟，长页面后面的内容不会等太久。
                    for (int i = 0; i < children.length; i++)
                      FadeSlideIn(
                        index: i > 5 ? 5 : i,
                        // 板块页的内容块普遍较高，位移幅度放小一点更稳
                        offset: 0.06,
                        child: children[i],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.topPadding,
    required this.showBack,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final double topPadding;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 28),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: c.isDark ? 0.34 : 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showBack)
            BounceTap(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            )
          else
            const SizedBox(height: 30),
          const SizedBox(height: 20),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 板块页面中使用的「功能占位 / 说明」小卡。
class PlaceholderCard extends StatelessWidget {
  const PlaceholderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.ink.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: c.inkFaint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
