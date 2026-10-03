import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../domain/section_meta.dart';

/// 板块入口卡片。
///
/// - 常规：2 列网格中的方块卡（图标 + 标题 + 副标题）
/// - [wide]：整行横向卡，用于第 5 个板块
class SectionTile extends StatelessWidget {
  const SectionTile({
    super.key,
    required this.section,
    this.wide = false,
  });

  final AppSection section;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final LinearGradient gradient = section.gradientOf(c);

    return BounceTap(
      onTap: () => context.push(section.route),
      scale: 0.97,
      child: Container(
        height: wide ? 108 : 148,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: gradient.colors.last
                  .withValues(alpha: c.isDark ? 0.32 : 0.30),
              blurRadius: 22,
              offset: const Offset(0, 12),
              spreadRadius: -10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(gradient: gradient),
            padding: const EdgeInsets.all(18),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -26,
                  bottom: -30,
                  child: IgnorePointer(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.13),
                      ),
                    ),
                  ),
                ),
                if (wide) _buildWide(context) else _buildSquare(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquare(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _IconBadge(icon: section.icon),
            const Spacer(),
            Icon(
              Icons.arrow_outward_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ],
        ),
        const Spacer(),
        Text(
          section.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          section.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      children: <Widget>[
        _IconBadge(icon: section.icon, size: 46),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                section.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                section.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(size * 0.33),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}
