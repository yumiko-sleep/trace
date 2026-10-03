import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../data/models/enums.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 分类选择器：今日目标 / 今年目标 / 人生目标。
class GoalCategorySelector extends StatelessWidget {
  const GoalCategorySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GoalCategory value;
  final ValueChanged<GoalCategory> onChanged;

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
          for (final GoalCategory cat in GoalCategory.values)
            Expanded(child: _segment(context, cat)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, GoalCategory cat) {
    final AppScheme c = context.scheme;
    final bool selected = cat == value;
    return BounceTap(
      onTap: () => onChanged(cat),
      haptic: false,
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF1FC4D8), Color(0xFF2E9BF7)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.medium,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : c.inkFaint,
            ),
            child: Text(cat.label),
          ),
        ),
      ),
    );
  }
}
