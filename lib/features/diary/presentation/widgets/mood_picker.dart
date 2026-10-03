import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../data/models/enums.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 心情对应的强调色。
Color moodColor(Mood mood, AppScheme c) => switch (mood) {
      Mood.happy => c.amber,
      Mood.calm => c.mintDeep,
      Mood.neutral => c.inkFaint,
      Mood.sad => c.sky,
      Mood.anxious => c.violet,
    };

/// 心情标签的小胶囊（列表里展示用）。
class MoodTag extends StatelessWidget {
  const MoodTag({super.key, required this.mood});

  final Mood mood;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color color = moodColor(mood, c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        mood.display,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// 心情选择器：再点一次已选中的可以取消选择。
class MoodPicker extends StatelessWidget {
  const MoodPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Mood? value;
  final ValueChanged<Mood?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: <Widget>[
        for (final Mood mood in Mood.values)
          _MoodChip(
            mood: mood,
            selected: value == mood,
            onTap: () => onChanged(value == mood ? null : mood),
          ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color color = moodColor(mood, c);
    return BounceTap(
      onTap: onTap,
      haptic: false,
      scale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : c.fieldFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.55) : c.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              scale: selected ? 1.15 : 1,
              duration: AppMotion.medium,
              curve: AppMotion.spring,
              child: Text(mood.emoji, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 7),
            AnimatedDefaultTextStyle(
              duration: AppMotion.medium,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? color : c.inkSoft,
              ),
              child: Text(mood.label),
            ),
          ],
        ),
      ),
    );
  }
}
