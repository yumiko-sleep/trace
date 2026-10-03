import 'package:flutter/material.dart';

import '../../../../core/widgets/gradient_button.dart';
import '../../../../data/models/enums.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 某个分类下还没有目标时的引导。
class EmptyGoalsView extends StatelessWidget {
  const EmptyGoalsView({
    super.key,
    required this.category,
    required this.onAdd,
  });

  final GoalCategory category;
  final VoidCallback onAdd;

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
                  c.cyan.withValues(alpha: 0.18),
                  c.sky.withValues(alpha: 0.14),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag_rounded,
              size: 28,
              color: c.sky,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '还没有${category.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            _hint(category),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: '添加第一个目标',
            icon: Icons.add_rounded,
            gradient: c.goals,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }

  String _hint(GoalCategory category) => switch (category) {
        GoalCategory.today => '今天想推进的一小步，写下来就更容易做到',
        GoalCategory.thisYear => '今年想拿到的结果，比如「读完 24 本书」',
        GoalCategory.life => '想成为的那个人，写大一点也没关系',
      };
}
