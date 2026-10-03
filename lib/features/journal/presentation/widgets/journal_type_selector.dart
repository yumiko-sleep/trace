import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../data/models/enums.dart';
import '../../domain/journal_stats.dart';
import 'journal_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 学习 / 训练 切换。
class JournalTypeSelector extends StatelessWidget {
  const JournalTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final JournalType value;
  final ValueChanged<JournalType> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: <Widget>[
          for (final JournalType t in JournalType.values)
            Expanded(child: _segment(context, t)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, JournalType type) {
    final AppScheme c = context.scheme;
    final bool selected = type == value;
    return BounceTap(
      onTap: () => onChanged(type),
      haptic: false,
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? journalGradient(type, c) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              journalIcon(type),
              size: 15,
              color: selected ? Colors.white : c.inkFaint,
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: AppMotion.medium,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : c.inkFaint,
              ),
              child: Text(type.shortLabel),
            ),
          ],
        ),
      ),
    );
  }
}
