import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/day_utils.dart';
import '../../../core/widgets/diary_media.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/section_scaffold.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/stats.dart';
import '../providers/diary_providers.dart';
import 'widgets/diary_entry_card.dart';
import 'widgets/empty_diary_view.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// 打开日记编辑页（全屏）。[date] 省略时默认今天。
void openDiaryEditor(BuildContext context, {DateTime? date}) {
  context.push(AppRoutes.diaryEditor, extra: date ?? DateTime.now());
}

/// 板块 3：日记（时间线）。
class DiaryPage extends ConsumerWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScheme c = context.scheme;
    final AsyncValue<List<DiaryEntry>> asyncEntries =
        ref.watch(diaryEntriesProvider);
    final List<DiaryEntry> entries =
        asyncEntries.valueOrNull ?? const <DiaryEntry>[];
    final Map<int, List<DiaryImage>> images =
        ref.watch(diaryImagesProvider).valueOrNull ??
            const <int, List<DiaryImage>>{};
    final DiaryStats stats = ref.watch(diaryStatsProvider);
    final bool loading = asyncEntries.isLoading && !asyncEntries.hasValue;
    final bool todayWritten = entries
        .any((DiaryEntry e) => DayUtils.isSameDay(e.date, DateTime.now()));

    return SectionScaffold(
      title: '日记',
      subtitle: '写下来，才算真正想清楚',
      icon: Icons.auto_stories_rounded,
      gradient: c.diary,
      bottomPadding: 120,
      floatingActionButton: PillActionButton(
        label: todayWritten ? '补写日记' : '写今天',
        icon: Icons.edit_rounded,
        gradient: c.diary,
        shadowColor: c.sky,
        onTap: () => openDiaryEditor(context),
      ),
      children: <Widget>[
        _SummaryCard(
          stats: stats,
          todayWritten: todayWritten,
          onWrite: () => openDiaryEditor(context),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: '成长轨迹',
          subtitle: stats.entries == 0
              ? '还没有记录'
              : '共 ${stats.entries} 篇 · 按时间倒序',
        ),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (entries.isEmpty)
          EmptyDiaryView(onWrite: () => openDiaryEditor(context))
        else
          for (final DiaryEntry entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DiaryEntryCard(
                entry: entry,
                images: images[entry.id] ?? const <DiaryImage>[],
                onTap: () => openDiaryEditor(context, date: entry.date),
                onImageTap: (int i) => openPhotoView(
                  context,
                  paths: (images[entry.id] ?? const <DiaryImage>[])
                      .map((DiaryImage img) => img.path)
                      .toList(growable: false),
                  initialIndex: i,
                ),
                onDelete: () => _delete(context, ref, entry,
                    images[entry.id] ?? const <DiaryImage>[]),
              ),
            ),
      ],
    );
  }

  /// 删除 + 撤销（连图片记录一起恢复）。
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DiaryEntry entry,
    List<DiaryImage> entryImages,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(diaryActionsProvider).remove(entry);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除 ${DayUtils.friendlyDate(entry.date)} 的日记'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () =>
                ref.read(diaryActionsProvider).restore(entry, entryImages),
          ),
        ),
      );
  }
}

/// 顶部汇总卡。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.stats,
    required this.todayWritten,
    required this.onWrite,
  });

  final DiaryStats stats;
  final bool todayWritten;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.diary,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.indigo.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: Icon(
              todayWritten
                  ? Icons.check_rounded
                  : Icons.edit_note_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '已记录 ${stats.days} 天',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${stats.entries} 篇日记 · ${stats.images} 张配图',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                if (todayWritten)
                  Text(
                    '今天已经写过了，随时可以补充',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 11.5,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: onWrite,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '今天还没写 → 现在就写',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
