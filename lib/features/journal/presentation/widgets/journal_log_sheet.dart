import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/day_utils.dart';
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

/// 打开「今日记录」弹窗。`log == null` 表示这天还没有记录。
Future<void> showJournalLogSheet(
  BuildContext context, {
  required JournalType type,
  required DateTime date,
  JournalLog? log,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (BuildContext _) =>
        _JournalLogSheet(type: type, date: date, log: log),
  );
}

class _JournalLogSheet extends ConsumerStatefulWidget {
  const _JournalLogSheet({
    required this.type,
    required this.date,
    this.log,
  });

  final JournalType type;
  final DateTime date;
  final JournalLog? log;

  @override
  ConsumerState<_JournalLogSheet> createState() => _JournalLogSheetState();
}

class _JournalLogSheetState extends ConsumerState<_JournalLogSheet> {
  late final TextEditingController _contentCtrl =
      TextEditingController(text: widget.log?.content ?? '');
  late final TextEditingController _durationCtrl = TextEditingController(
    text: widget.log?.durationMinutes?.toString() ?? '',
  );

  late int? _planId = widget.log?.planId;

  /// 和任务 / 目标弹窗同样的处理：等入场动画跑完再拉键盘。
  final FocusNode _contentFocus = FocusNode();

  String? _error;
  bool _saving = false;

  static const List<int> _quickMinutes = <int>[20, 30, 45, 60, 90, 120];

  bool get _isEdit => widget.log != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      Future<void>.delayed(const Duration(milliseconds: 340), () {
        if (mounted) _contentFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _durationCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String content = _contentCtrl.text.trim();
    final String durationText = _durationCtrl.text.trim();
    final int? duration =
        durationText.isEmpty ? null : int.tryParse(durationText);

    if (durationText.isNotEmpty && duration == null) {
      setState(() => _error = '时长要填分钟数');
      return;
    }
    if (content.isEmpty && duration == null) {
      setState(() => _error = '写点什么，或者填个时长');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    await ref.read(journalActionsProvider).saveLog(
          type: widget.type,
          date: widget.date,
          content: content,
          durationMinutes: duration,
          planId: _planId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final JournalLog log = widget.log!;
    final NavigatorState navigator = Navigator.of(context);
    await ref.read(journalActionsProvider).removeLog(log);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final List<JournalPlan> plans =
        ref.watch(journalPlansProvider).valueOrNull ?? const <JournalPlan>[];
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight = (mq.size.height - mq.viewInsets.bottom) * 0.94;
    final Color color = journalColor(widget.type);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
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
                          JournalIconBadge(type: widget.type, size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  _isEdit
                                      ? '编辑${widget.type.shortLabel}记录'
                                      : '记录${widget.type.shortLabel}',
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DayUtils.friendlyDate(widget.date),
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
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
                          controller: _contentCtrl,
                          focusNode: _contentFocus,
                          hint: widget.type.contentHint,
                          maxLines: 4,
                          errorText: _error,
                        ),
                        const SizedBox(height: 18),
                        const SheetLabel('时长（分钟，可选）'),
                        const SizedBox(height: 8),
                        SheetField(
                          controller: _durationCtrl,
                          hint: '例如 60',
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final int m in _quickMinutes)
                              SheetChoice(
                                label: '$m',
                                color: color,
                                dense: true,
                                selected:
                                    _durationCtrl.text.trim() == '$m',
                                onTap: () => setState(() {
                                  _durationCtrl.text = '$m';
                                  _error = null;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const SheetLabel('关联计划（可选）'),
                        const SizedBox(height: 8),
                        if (plans.isEmpty)
                          Text(
                            '还没有${widget.type.planTitle}，回到页面先建一个，这里就能选上了。',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.6,
                              color: c.inkFaint,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              SheetChoice(
                                label: '不关联',
                                color: c.inkFaint,
                                selected: _planId == null,
                                dense: true,
                                onTap: () => setState(() => _planId = null),
                              ),
                              for (final JournalPlan p in plans)
                                SheetChoice(
                                  label: p.title,
                                  color: color,
                                  selected: _planId == p.id,
                                  dense: true,
                                  onTap: () => setState(() => _planId = p.id),
                                ),
                            ],
                          ),
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
                                '删除这条记录',
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
