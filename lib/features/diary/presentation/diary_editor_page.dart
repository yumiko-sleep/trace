import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/day_utils.dart';
import '../../../core/widgets/bounce_tap.dart';
import '../../../core/widgets/diary_media.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../../data/services/image_storage.dart';
import '../providers/diary_providers.dart';
import 'widgets/mood_picker.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// 日记编辑页（全屏）。
///
/// 打开时会按日期加载已有日记和配图；保存时整体替换。
class DiaryEditorPage extends ConsumerStatefulWidget {
  const DiaryEditorPage({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends ConsumerState<DiaryEditorPage> {
  static const int _maxImages = 9;

  final TextEditingController _contentCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  late DateTime _date = DayUtils.dayStart(widget.date);
  Mood? _mood;
  List<DiaryImage> _existing = <DiaryImage>[];
  final List<String> _added = <String>[];
  final List<DiaryImage> _removed = <DiaryImage>[];

  bool _loading = true;
  bool _saving = false;
  String? _hint;
  int? _entryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final DiaryRepository repo = ref.read(diaryRepositoryProvider);
    final DiaryEntry? entry = await repo.getByDay(_date);
    final List<DiaryImage> images =
        entry == null ? <DiaryImage>[] : await repo.getImages(entry.id);
    if (!mounted) return;
    setState(() {
      _entryId = entry?.id;
      _contentCtrl.text = entry?.content ?? '';
      _mood = entry?.mood;
      _existing = images;
      _added.clear();
      _removed.clear();
      _loading = false;
    });
  }

  List<String> get _allPaths => <String>[
        ..._existing.map((DiaryImage i) => i.path),
        ..._added,
      ];

  Future<void> _pickImages() async {
    final int remain = _maxImages - _allPaths.length;
    if (remain <= 0) return;
    final List<String> paths = await ImageStorage.pickAndSave(limit: remain);
    if (paths.isEmpty || !mounted) return;
    setState(() {
      _added.addAll(paths);
      _hint = null;
    });
  }

  void _removeAt(int index) {
    if (index < _existing.length) {
      setState(() => _removed.add(_existing.removeAt(index)));
    } else {
      final String path = _added.removeAt(index - _existing.length);
      // 刚加的图，直接从磁盘删掉
      ImageStorage.delete(path);
      setState(() {});
    }
  }

  void _previewAt(int index) {
    openPhotoView(context, paths: _allPaths, initialIndex: index);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择日期',
    );
    if (picked == null) return;
    setState(() {
      _date = DayUtils.dayStart(picked);
      _loading = true;
      _entryId = null;
      _mood = null;
      _existing = <DiaryImage>[];
      _added.clear();
      _removed.clear();
      _contentCtrl.clear();
    });
    await _load();
  }

  Future<void> _save() async {
    final String content = _contentCtrl.text.trim();
    final List<String> paths = _allPaths;

    if (content.isEmpty && paths.isEmpty) {
      // 原来写过、现在全清空了 → 直接删掉这篇
      if (_entryId != null) {
        await ref.read(diaryActionsProvider).removeById(_entryId!);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      setState(() => _hint = '写点什么，或者加张图片吧');
      return;
    }

    setState(() {
      _saving = true;
      _hint = null;
    });

    // 用户主动移除的配图，文件一并删掉
    await ImageStorage.deleteAll(
      _removed.map((DiaryImage i) => i.path).toList(),
    );

    await ref.read(diaryActionsProvider).save(
          date: _date,
          content: content,
          mood: _mood,
          imagePaths: paths,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Scaffold(
      backgroundColor: c.bgTop,
      body: GradientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              : Column(
                  children: <Widget>[
                    _header(context),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  '今天的心情',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.inkFaint,
                                  ),
                                ),
                                if (_mood != null) ...<Widget>[
                                  const SizedBox(width: 8),
                                  BounceTap(
                                    onTap: () => setState(() => _mood = null),
                                    haptic: false,
                                    child: Text(
                                      '清除',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.inkFaint,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            MoodPicker(
                              value: _mood,
                              onChanged: (Mood? m) => setState(() => _mood = m),
                            ),
                            const SizedBox(height: 20),
                            _contentField(),
                            const SizedBox(height: 20),
                            Text(
                              '配图（可选）',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.inkFaint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DiaryImageEditor(
                              paths: _allPaths,
                              maxImages: _maxImages,
                              onRemove: _removeAt,
                              onAdd: _pickImages,
                              onPreview: _previewAt,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final AppScheme c = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Row(
        children: <Widget>[
          BounceTap(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.fieldFill,
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 19,
                color: c.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: BounceTap(
              onTap: _pickDate,
              haptic: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        DayUtils.friendlyDate(_date),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: c.inkFaint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hint ??
                        '${DayUtils.weekday(_date)} · ${_entryId == null ? '还没写过' : '已写过，可继续修改'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _hint == null
                          ? c.inkFaint
                          : c.danger,
                      fontWeight:
                          _hint == null ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          BounceTap(
            onTap: _saving ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                gradient: _saving ? null : c.diary,
                color: _saving ? c.inkFaint : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _saving
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                          color: c.sky.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                          spreadRadius: -6,
                        ),
                      ],
              ),
              child: Text(
                _saving ? '保存中' : '保存',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentField() {
    final AppScheme c = context.scheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: TextField(
        controller: _contentCtrl,
        focusNode: _focus,
        maxLines: null,
        minLines: 8,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: c.mint,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.75,
          color: c.ink,
        ),
        onChanged: (_) {
          if (_hint != null) setState(() => _hint = null);
        },
        decoration: InputDecoration(
          hintText: '今天发生了什么？想记住什么？\n\n不用写很多，一句话也可以。',
          hintStyle: TextStyle(
            color: c.isDark ? c.inkSoft : c.inkFaint,
            fontSize: 14,
            height: 1.7,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
