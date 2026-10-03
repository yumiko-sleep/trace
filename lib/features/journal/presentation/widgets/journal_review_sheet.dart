import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../data/models/enums.dart';
import '../../domain/journal_stats.dart';
import '../../providers/journal_providers.dart';
import 'journal_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 打开「复盘」弹窗（写今天这一段总结）。
Future<void> showJournalReviewSheet(
  BuildContext context, {
  required JournalType type,
  required DateTime date,
  String initialReview = '',
}) {
  final AppScheme c = context.scheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: c.ink.withValues(alpha: 0.30),
    builder: (BuildContext _) => _JournalReviewSheet(
      type: type,
      date: date,
      initialReview: initialReview,
    ),
  );
}

class _JournalReviewSheet extends ConsumerStatefulWidget {
  const _JournalReviewSheet({
    required this.type,
    required this.date,
    required this.initialReview,
  });

  final JournalType type;
  final DateTime date;
  final String initialReview;

  @override
  ConsumerState<_JournalReviewSheet> createState() =>
      _JournalReviewSheetState();
}

class _JournalReviewSheetState extends ConsumerState<_JournalReviewSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialReview);
  final FocusNode _focus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 340), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    setState(() => _saving = true);
    await ref.read(journalActionsProvider).saveReview(
          type: widget.type,
          date: widget.date,
          review: clear ? '' : _ctrl.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight = (mq.size.height - mq.viewInsets.bottom) * 0.94;
    final Color color = journalColor(widget.type);
    final bool hasReview = widget.initialReview.trim().isNotEmpty;

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
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.insights_rounded,
                              size: 19,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  '${widget.type.shortLabel}复盘',
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
                          controller: _ctrl,
                          focusNode: _focus,
                          hint: widget.type.reviewHint,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '复盘是给未来的自己看的：今天卡在哪、明天先做哪一步。'
                          '（阶段 7 的 AI 复盘会把这段和当天数据一起读进去）',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.6,
                            color: c.inkFaint,
                          ),
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
                        label: _saving ? '保存中…' : '保存复盘',
                        icon: Icons.check_rounded,
                        gradient: journalGradient(widget.type, c),
                        onPressed: _saving ? null : _save,
                      ),
                      if (hasReview)
                        BounceTap(
                          onTap: _saving ? null : () => _save(clear: true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                '清空复盘',
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
