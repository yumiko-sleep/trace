import 'package:flutter/material.dart';

import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 还没有写过日记时的引导。
class EmptyDiaryView extends StatelessWidget {
  const EmptyDiaryView({super.key, required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  c.sky.withValues(alpha: 0.18),
                  c.indigo.withValues(alpha: 0.14),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              size: 28,
              color: c.sky,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '还没有写过日记',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            '写下来，才算真正想清楚。\n可以只写一句话，也可以配几张图。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: '写今天的日记',
            icon: Icons.edit_rounded,
            gradient: c.diary,
            onPressed: onWrite,
          ),
        ],
      ),
    );
  }
}
