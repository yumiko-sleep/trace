import 'package:flutter/material.dart';

import '../../../../core/widgets/swipe_to_delete.dart';
import '../../../../data/db/app_database.dart';
import 'journal_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 计划卡：标题 + 正文摘要 + 启用状态，左滑删除、点一下编辑。
class JournalPlanCard extends StatelessWidget {
  const JournalPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    required this.onDelete,
  });

  final JournalPlan plan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color color = journalColor(plan.type);
    final String content = plan.content.trim();

    return SwipeToDelete(
      onDelete: onDelete,
      onTap: onTap,
      radius: 22,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.ink.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  JournalIconBadge(type: plan.type, size: 32),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: plan.isActive ? c.ink : c.inkFaint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  JournalTag(
                    text: plan.isActive ? '启用中' : '已停用',
                    color: plan.isActive ? color : c.inkFaint,
                  ),
                ],
              ),
              if (content.isNotEmpty) ...<Widget>[
                const SizedBox(height: 9),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: c.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
