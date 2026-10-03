import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../domain/journal_stats.dart';
import '../../providers/journal_providers.dart';
import 'journal_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 打开计划的新建 / 编辑弹窗。
Future<void> showJournalPlanSheet(
  BuildContext context, {
  required JournalType type,
  JournalPlan? plan,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (BuildContext _) => _JournalPlanSheet(type: type, plan: plan),
  );
}

class _JournalPlanSheet extends ConsumerStatefulWidget {
  const _JournalPlanSheet({required this.type, this.plan});

  final JournalType type;
  final JournalPlan? plan;

  @override
  ConsumerState<_JournalPlanSheet> createState() => _JournalPlanSheetState();
}

class _JournalPlanSheetState extends ConsumerState<_JournalPlanSheet> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.plan?.title ?? '');
  late final TextEditingController _contentCtrl =
      TextEditingController(text: widget.plan?.content ?? '');
  late bool _active = widget.plan?.isActive ?? true;

  final FocusNode _titleFocus = FocusNode();
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.plan != null;

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
    _contentCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '给计划起个名字吧');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final JournalActions actions = ref.read(journalActionsProvider);
    if (_isEdit) {
      await actions.updatePlan(
        widget.plan!.id,
        title: title,
        content: _contentCtrl.text.trim(),
        isActive: _active,
      );
    } else {
      await actions.addPlan(
        type: widget.type,
        title: title,
        content: _contentCtrl.text.trim(),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final NavigatorState navigator = Navigator.of(context);
    await ref.read(journalActionsProvider).removePlan(widget.plan!);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight = (mq.size.height - mq.viewInsets.bottom) * 0.94;
    final Color color = journalColor(widget.type);

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
                              _isEdit
                                  ? '编辑${widget.type.planTitle}'
                                  : '新建${widget.type.planTitle}',
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
                          hint: widget.type == JournalType.study
                              ? '例如「数学一轮复习」'
                              : '例如「推 / 拉 / 腿 三分化」',
                          errorText: _error,
                        ),
                        const SizedBox(height: 12),
                        SheetField(
                          controller: _contentCtrl,
                          hint: widget.type == JournalType.study
                              ? '计划正文：章节、资料、每周目标（可留空）'
                              : '计划正文：动作、组数、次数、重量安排（可留空）',
                          maxLines: 6,
                        ),
                        if (_isEdit) ...<Widget>[
                          const SizedBox(height: 18),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      '启用这个计划',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _active
                                          ? '启用中：记录时可以关联到它'
                                          : '已停用：历史记录不受影响，只是不再出现在记录里',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.5,
                                        color: c.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _active,
                                activeThumbColor: color,
                                onChanged: (bool v) =>
                                    setState(() => _active = v),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GradientButton(
                        label: _saving ? '保存中…' : '保存',
                        icon: Icons.check_rounded,
                        gradient: journalGradient(widget.type, c),
                        onPressed: _saving ? null : _save,
                      ),
                      if (_isEdit)
                        BounceTap(
                          onTap: _saving ? null : _delete,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                '删除这个计划（历史记录会保留）',
                                style: TextStyle(
                                  fontSize: 13,
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
