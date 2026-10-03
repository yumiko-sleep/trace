import 'package:flutter/material.dart';

import '../../../../core/widgets/bounce_tap.dart';
import '../../../../data/models/enums.dart';
import '../../domain/journal_stats.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 学习 / 训练 的图标、强调色与渐变。
IconData journalIcon(JournalType type) => switch (type) {
      JournalType.study => Icons.menu_book_rounded,
      JournalType.training => Icons.fitness_center_rounded,
    };

Color journalColor(JournalType type) => Color(type.accentHex);

LinearGradient journalGradient(JournalType type, AppScheme c) => switch (type) {
      JournalType.study => c.journal,
      // 训练用偏蓝的一条，和学习在视觉上区分开
      JournalType.training => c.goals,
    };

/// 小圆角图标徽章。
class JournalIconBadge extends StatelessWidget {
  const JournalIconBadge({
    super.key,
    required this.type,
    this.size = 40,
    this.filled = false,
  });

  final JournalType type;
  final double size;

  /// true = 实心渐变底 + 白色图标（用于渐变卡上）。
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: filled ? journalGradient(type, c) : null,
        color: filled ? null : journalColor(type).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        journalIcon(type),
        size: size * 0.5,
        color: filled ? Colors.white : journalColor(type),
      ),
    );
  }
}

/// 淡色胶囊标签。
class JournalTag extends StatelessWidget {
  const JournalTag({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态通用构件。
class JournalEmptyHint extends StatelessWidget {
  const JournalEmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color tint = color ?? c.violet;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: c.inkFaint,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 14),
            BounceTap(
              onTap: onAction,
              child: JournalTag(
                text: actionLabel!,
                color: tint,
                icon: Icons.add_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
