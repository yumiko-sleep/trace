import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/stats.dart';
import '../../providers/goal_providers.dart';
import 'goal_card.dart' show deadlineColor, deadlineText, statusColor;
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 打开新建 / 编辑目标的底部弹窗。
Future<void> showGoalEditor(BuildContext context, {Goal? goal}) {
  return showAppSheet<void>(
    context: context,
    builder: (BuildContext _) => _GoalEditorSheet(goal: goal),
  );
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  const _GoalEditorSheet({this.goal});

  final Goal? goal;

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.goal?.title ?? '');
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.goal?.description ?? '');
  late GoalCategory _category =
      widget.goal?.category ?? ref.read(goalCategoryProvider);
  late GoalStatus _status = widget.goal?.status ?? GoalStatus.active;
  late DateTime? _deadline = widget.goal?.deadline;
  late double _progress = widget.goal?.progress ?? 0;
  late int? _parentId = widget.goal?.parentId;

  /// 和任务弹窗同样的处理：等入场动画结束再拉起键盘，避免两段动画打架。
  final FocusNode _titleFocus = FocusNode();

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.goal != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      Future<void>.delayed(const Duration(milliseconds: 340), () {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '给目标起个名字吧');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final GoalActions actions = ref.read(goalActionsProvider);
    final String desc = _descCtrl.text.trim();

    if (_isEdit) {
      await actions.update(
        widget.goal!.id,
        title: title,
        description: desc,
        category: _category,
        progress: _progress,
        deadline: _deadline,
        clearDeadline: _deadline == null,
        status: _status,
        parentId: _parentId,
        clearParent: _parentId == null,
      );
    } else {
      await actions.add(
        title: title,
        category: _category,
        description: desc,
        progress: _progress,
        deadline: _deadline,
        status: _status,
        parentId: _parentId,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '选择截止日期',
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _delete() async {
    final Goal goal = widget.goal!;
    final NavigatorState navigator = Navigator.of(context);
    await ref.read(goalActionsProvider).remove(goal);
    navigator.pop();
  }

  /// 切换分类，并清掉不再合法的「上一级目标」。
  void _changeCategory(GoalCategory c) {
    setState(() {
      _category = c;
      _parentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final List<Goal> allGoals =
        ref.watch(allGoalsProvider).valueOrNull ?? const <Goal>[];
    final Map<int, DayTaskStats> taskStats =
        ref.watch(goalTaskStatsProvider).valueOrNull ??
            const <int, DayTaskStats>{};

    final GoalCategory? parentCategory = parentCategoryOf(_category);
    final List<Goal> parentCandidates = parentCategory == null
        ? const <Goal>[]
        : allGoals
            .where((Goal g) => g.category == parentCategory)
            .toList(growable: false);

    final DayTaskStats? linked = _isEdit ? taskStats[widget.goal!.id] : null;

    // 减去键盘高度，保证「底部按钮区」永远留在屏幕内
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight = (mq.size.height - mq.viewInsets.bottom) * 0.94;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: RepaintBoundary(
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ---------- 固定的头部 ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.line,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _isEdit ? '编辑目标' : '新建目标',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          BounceTap(
                            onTap: () => Navigator.of(context).pop(),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: c.inkFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),

                // ---------- 可滚动的表单 ----------
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SheetField(
                          controller: _titleCtrl,
                          focusNode: _titleFocus,
                          hint: '想达成什么？',
                          errorText: _error,
                        ),
                        const SizedBox(height: 12),
                        SheetField(
                          controller: _descCtrl,
                          hint: '补充说明（可选）',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 18),
                        const SheetLabel('属于'),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            for (final GoalCategory gc in GoalCategory.values)
                              ...<Widget>[
                                Expanded(
                                  child: SheetChoice(
                                    label: gc.label,
                                    color: c.sky,
                                    selected: _category == gc,
                                    onTap: () => _changeCategory(gc),
                                  ),
                                ),
                                if (gc != GoalCategory.values.last)
                                  const SizedBox(width: 10),
                              ],
                          ],
                        ),
                        const SizedBox(height: 18),
                        const SheetLabel('状态'),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            for (final GoalStatus s in GoalStatus.values)
                              ...<Widget>[
                                Expanded(
                                  child: SheetChoice(
                                    label: s.label,
                                    color: statusColor(s, c),
                                    selected: _status == s,
                                    onTap: () => setState(() => _status = s),
                                  ),
                                ),
                                if (s != GoalStatus.values.last)
                                  const SizedBox(width: 10),
                              ],
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            const SheetLabel('进度'),
                            const Spacer(),
                            Text(
                              '${(_progress * 100).round()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: c.mintDeep,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: c.mint,
                            inactiveTrackColor: c.line,
                            thumbColor: Colors.white,
                            overlayColor:
                                c.mint.withValues(alpha: 0.12),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                              elevation: 3,
                            ),
                          ),
                          child: Slider(
                            value: _progress,
                            divisions: 20,
                            onChanged: (double v) =>
                                setState(() => _progress = v),
                          ),
                        ),
                        if (linked != null && !linked.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: BounceTap(
                              onTap: () => setState(
                                () => _progress = linked.progress,
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '按关联任务计算（${linked.done}/${linked.total} → ${(linked.progress * 100).round()}%）',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.sky,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        const SheetLabel('截止日期'),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: BounceTap(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.bgBottom.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: c.line),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.event_rounded,
                                        size: 16,
                                        color: deadlineColor(_deadline, c),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _deadline == null
                                            ? '未设置'
                                            : '${DayUtils.formatDate(_deadline!)}  ·  ${deadlineText(_deadline)}',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: c.ink,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.expand_more_rounded,
                                        size: 18,
                                        color: c.inkFaint,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_deadline != null) ...<Widget>[
                              const SizedBox(width: 10),
                              BounceTap(
                                onTap: () => setState(() => _deadline = null),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: c.bgBottom.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: c.line),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: c.inkFaint,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (parentCandidates.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 18),
                          SheetLabel('上一级目标（${parentCategory!.label}）'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              SheetChoice(
                                label: '不关联',
                                color: c.inkFaint,
                                selected: _parentId == null,
                                dense: true,
                                onTap: () => setState(() => _parentId = null),
                              ),
                              for (final Goal g in parentCandidates)
                                SheetChoice(
                                  label: g.title,
                                  color: c.violet,
                                  selected: _parentId == g.id,
                                  dense: true,
                                  onTap: () => setState(() => _parentId = g.id),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ---------- 固定在底部的操作区 ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GradientButton(
                        label: _saving ? '保存中…' : '保存',
                        icon: Icons.check_rounded,
                        gradient: c.goals,
                        onPressed: _saving ? null : _save,
                      ),
                      if (_isEdit)
                        BounceTap(
                          onTap: _saving ? null : _delete,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                '删除这个目标',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.danger,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
