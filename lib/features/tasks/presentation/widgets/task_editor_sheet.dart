import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../data/db/app_database.dart';
import '../../../goals/providers/goal_providers.dart';
import '../../providers/task_providers.dart';
import 'task_tile.dart' show priorityColor, priorityLabel;
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 打开新建 / 编辑任务的底部弹窗。
Future<void> showTaskEditor(BuildContext context, {Task? task}) {
  return showAppSheet<void>(
    context: context,
    builder: (BuildContext _) => _TaskEditorSheet(task: task),
  );
}

class _TaskEditorSheet extends ConsumerStatefulWidget {
  const _TaskEditorSheet({this.task});

  final Task? task;

  @override
  ConsumerState<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<_TaskEditorSheet> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.task?.title ?? '');
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.task?.note ?? '');
  late DateTime _dueDate = widget.task?.dueDate ?? DateTime.now();
  late int _priority = widget.task?.priority ?? 1;
  late int? _goalId = widget.task?.goalId;

  /// 标题输入框的焦点。
  ///
  /// 这里**故意不用 autofocus**：autofocus 会让「弹窗滑入」和「键盘弹起 + 窗口
  /// 重新布局」同时发生，中低端机上就是肉眼可见的一卡。改成等弹窗入场动画
  /// 跑完（默认 250ms）再拉起键盘，两段动画错开，主观上顺很多。
  final FocusNode _titleFocus = FocusNode();

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.task != null;

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
    _noteCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '给任务起个名字吧');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final TaskActions actions = ref.read(taskActionsProvider);
    final String note = _noteCtrl.text.trim();

    if (_isEdit) {
      await actions.update(
        widget.task!.id,
        title: title,
        note: note,
        dueDate: _dueDate,
        goalId: _goalId,
        clearGoal: _goalId == null,
        priority: _priority,
      );
    } else {
      await actions.add(
        title: title,
        note: note,
        dueDate: _dueDate,
        goalId: _goalId,
        priority: _priority,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '选择日期',
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _delete() async {
    final Task task = widget.task!;
    final NavigatorState navigator = Navigator.of(context);
    await ref.read(taskActionsProvider).remove(task);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final List<Goal> goals =
        ref.watch(allGoalsProvider).valueOrNull ?? const <Goal>[];

    // 减去键盘高度，保证「底部按钮区」永远留在屏幕内
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight =
        (mq.size.height - mq.viewInsets.bottom) * 0.94;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      // 弹窗内容做成独立图层：滑入时只做位移，不必逐帧重绘里面的所有圆角/边框/阴影
      child: RepaintBoundary(
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                              _isEdit ? '编辑任务' : '新建任务',
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
                          hint: '要做什么？',
                          errorText: _error,
                        ),
                        const SizedBox(height: 12),
                        SheetField(
                          controller: _noteCtrl,
                          hint: '备注（可选）',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 18),
                        const SheetLabel('日期'),
                        const SizedBox(height: 8),
                        BounceTap(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: c.fieldFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.line),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: c.inkSoft,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DayUtils.formatDate(_dueDate),
                                  style: TextStyle(
                                    fontSize: 14,
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
                        const SizedBox(height: 18),
                        const SheetLabel('优先级'),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            for (final int p in <int>[0, 1, 2]) ...<Widget>[
                              Expanded(
                                child: SheetChoice(
                                  label: priorityLabel(p),
                                  color: priorityColor(p, c),
                                  selected: _priority == p,
                                  onTap: () => setState(() => _priority = p),
                                ),
                              ),
                              if (p != 2) const SizedBox(width: 10),
                            ],
                          ],
                        ),
                        if (goals.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 18),
                          const SheetLabel('关联目标'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              SheetChoice(
                                label: '不关联',
                                color: c.inkFaint,
                                selected: _goalId == null,
                                dense: true,
                                onTap: () => setState(() => _goalId = null),
                              ),
                              for (final Goal g in goals)
                                SheetChoice(
                                  label: g.title,
                                  color: c.sky,
                                  selected: _goalId == g.id,
                                  dense: true,
                                  onTap: () => setState(() => _goalId = g.id),
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
                        onPressed: _saving ? null : _save,
                      ),
                      if (_isEdit)
                        BounceTap(
                          onTap: _saving ? null : _delete,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                '删除这个任务',
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
