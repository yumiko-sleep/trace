import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../domain/metric_stats.dart';
import '../../providers/metric_providers.dart';
import 'metric_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 打开某个数据项的取值弹窗。
///
/// [current] 为当天已有的值（null 表示这天还没记录）。
Future<void> showMetricValueSheet(
  BuildContext context, {
  required MetricDefinition def,
  required DateTime day,
  double? current,
}) {
  final AppScheme c = context.scheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: c.ink.withValues(alpha: 0.30),
    builder: (BuildContext _) =>
        _MetricValueSheet(def: def, day: day, current: current),
  );
}

class _MetricValueSheet extends ConsumerStatefulWidget {
  const _MetricValueSheet({
    required this.def,
    required this.day,
    this.current,
  });

  final MetricDefinition def;
  final DateTime day;
  final double? current;

  @override
  ConsumerState<_MetricValueSheet> createState() => _MetricValueSheetState();
}

class _MetricValueSheetState extends ConsumerState<_MetricValueSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.current == null ? '' : trimNumber(widget.current!),
  );

  /// 时间点类型用「当天的分钟数」保存。
  late double? _value = widget.current;
  String? _error;
  bool _saving = false;

  MetricDefinition get _def => widget.def;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final int minutes = (_value ?? 23 * 60).round().clamp(0, 1439);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: '选择${_def.name}',
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      setState(() {
        _error = null;
        _value = (picked.hour * 60 + picked.minute).toDouble();
      });
    }
  }

  void _onTextChanged(String text) {
    final double? parsed = double.tryParse(text.trim());
    setState(() {
      _error = null;
      _value = parsed;
    });
  }

  Future<void> _save() async {
    final double? value = _value;
    if (value == null) {
      setState(() => _error = _def.valueType == MetricValueType.clock
          ? '先选一个时间吧'
          : '填一个数字吧');
      return;
    }
    if (value < 0) {
      setState(() => _error = '不能是负数');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    await ref.read(metricActionsProvider).setValue(
          metricId: _def.id,
          day: widget.day,
          value: value,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    final NavigatorState navigator = Navigator.of(context);
    await ref.read(metricActionsProvider).clearValue(
          metricId: _def.id,
          day: widget.day,
        );
    navigator.pop();
  }

  /// 快速填值用的候选（时长类给一组常用分钟数）。
  List<double> get _quickValues => switch (_def.valueType) {
        MetricValueType.duration => const <double>[10, 20, 30, 45, 60, 90],
        MetricValueType.number => const <double>[],
        MetricValueType.clock => const <double>[],
      };

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight = (mq.size.height - mq.viewInsets.bottom) * 0.94;
    final double? value = _value;

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
                // ---------- 固定头部 ----------
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
                          MetricIconBadge(
                            iconKey: _def.iconKey,
                            color: Color(_def.colorHex),
                            size: 38,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  _def.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${DayUtils.friendlyDate(widget.day)} · '
                                  '${_def.valueType.label}'
                                  '${_def.unit.isEmpty ? '' : '（${_def.unit}）'}',
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ---------- 可滚动的主体 ----------
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_def.valueType == MetricValueType.clock) ...<Widget>[
                          _ClockPicker(
                            text: value == null
                                ? '点这里选时间'
                                : DayUtils.minutesToClock(value),
                            selected: value != null,
                            color: Color(_def.colorHex),
                            onTap: _pickTime,
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.danger,
                              ),
                            ),
                          ],
                        ] else
                          SheetField(
                            controller: _ctrl,
                            hint: _def.unit.isEmpty
                                ? '填一个数字'
                                : '填一个数字（${_def.unit}）',
                            errorText: _error,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _numericFormatters,
                            onChanged: _onTextChanged,
                          ),
                        if (_quickValues.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          const SheetLabel('常用'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final double q in _quickValues)
                                SheetChoice(
                                  label: trimNumber(q),
                                  color: Color(_def.colorHex),
                                  selected: value == q,
                                  dense: true,
                                  onTap: () {
                                    _ctrl.text = trimNumber(q);
                                    setState(() {
                                      _error = null;
                                      _value = q;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        _TargetHint(def: _def, value: value),
                      ],
                    ),
                  ),
                ),

                // ---------- 固定底部 ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GradientButton(
                        label: _saving ? '保存中…' : '保存',
                        icon: Icons.check_rounded,
                        gradient: c.metrics,
                        onPressed: _saving ? null : _save,
                      ),
                      if (widget.current != null)
                        BounceTap(
                          onTap: _saving ? null : _clear,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                '清除这天的记录',
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

/// 时间点类型的大号选择按钮。
class _ClockPicker extends StatelessWidget {
  const _ClockPicker({
    required this.text,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return BounceTap(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : c.line,
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              text,
              style: TextStyle(
                fontSize: selected ? 34 : 17,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: selected ? color : c.inkFaint,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '轻点选择 24 小时制时间',
              style: TextStyle(fontSize: 12, color: c.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// 目标值提示 + 实时达标判断。
class _TargetHint extends StatelessWidget {
  const _TargetHint({required this.def, required this.value});

  final MetricDefinition def;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final double? target = def.targetValue;
    if (target == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.bgBottom.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Text(
          '这个数据项还没设目标值，去「管理数据项」里补一个就能统计达标率。',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: c.inkFaint,
          ),
        ),
      );
    }

    final bool lower = metricLowerIsBetter(def);
    final String targetText = formatMetricValue(def, target);
    final bool? achieved =
        value == null ? null : (lower ? value! <= target : value! >= target);
    final Color color = achieved == true ? c.mintDeep : c.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            achieved == true
                ? Icons.emoji_events_rounded
                : Icons.flag_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '目标 ${lower ? '不超过' : '不少于'} $targetText',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.inkSoft,
              ),
            ),
          ),
          if (achieved != null)
            MetricTag(
              text: achieved ? '达标' : '未达标',
              color: color,
            ),
        ],
      ),
    );
  }
}

/// 数字键盘的输入过滤（只允许数字与一个小数点）。
final List<TextInputFormatter> _numericFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];
