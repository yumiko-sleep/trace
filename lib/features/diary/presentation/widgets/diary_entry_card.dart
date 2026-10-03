import 'package:flutter/material.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/diary_media.dart';
import '../../../../core/widgets/swipe_to_delete.dart';
import '../../../../data/db/app_database.dart';
import 'mood_picker.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 时间线上的一篇日记卡片。
///
/// 左侧日期 + 心情，下面是配图缩略图行和正文摘要；点一下进入编辑，左滑删除。
class DiaryEntryCard extends StatelessWidget {
  const DiaryEntryCard({
    super.key,
    required this.entry,
    required this.images,
    required this.onTap,
    required this.onDelete,
    required this.onImageTap,
  });

  final DiaryEntry entry;
  final List<DiaryImage> images;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<int> onImageTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final List<String> paths =
        images.map((DiaryImage i) => i.path).toList(growable: false);
    final String content = entry.content.trim();

    return SwipeToDelete(
      onDelete: onDelete,
      onTap: onTap,
      radius: 22,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
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
                  Text(
                    DayUtils.friendlyDate(entry.date),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    DayUtils.weekday(entry.date),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.inkFaint,
                    ),
                  ),
                  const Spacer(),
                  if (entry.mood != null) MoodTag(mood: entry.mood!),
                ],
              ),
              if (paths.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                DiaryThumbRow(paths: paths, onTap: onImageTap),
              ],
              if (content.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: c.inkSoft,
                  ),
                ),
              ],
              if (paths.isEmpty && content.isEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '（这篇还是空的）',
                  style: TextStyle(fontSize: 12.5, color: c.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
