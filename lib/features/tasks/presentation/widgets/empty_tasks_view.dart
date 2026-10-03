import 'package:flutter/material.dart';

import '../../../../core/widgets/gradient_button.dart';
import '../../providers/task_providers.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 空状态：没有任务 / 筛选后没有结果。
class EmptyTasksView extends StatelessWidget {
  const EmptyTasksView({
    super.key,
    required this.filter,
    required this.onAdd,
  });

  final TaskFilter filter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final bool filtered = filter != TaskFilter.all;

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
                  c.mint.withValues(alpha: 0.18),
                  c.cyan.withValues(alpha: 0.14),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              filtered
                  ? Icons.filter_alt_off_rounded
                  : Icons.checklist_rounded,
              size: 30,
              color: c.mintDeep,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            filtered ? '这里还没有任务' : '今天还没有任务',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            filtered ? '换个筛选条件看看' : '从一件小事开始吧，完成后勾掉它',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!filtered) ...<Widget>[
            const SizedBox(height: 20),
            GradientButton(
              label: '添加第一个任务',
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}
