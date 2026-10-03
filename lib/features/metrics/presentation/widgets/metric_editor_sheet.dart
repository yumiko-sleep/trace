import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../../../data/db/app_database.dart';
import '../../../../data/models/enums.dart';
import '../../domain/metric_stats.dart';
import '../../providers/metric_providers.dart';
import 'metric_visuals.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 新增 / 编辑数据项。`def == null` 表示新增。
Future<void> showMetricEditorSheet(
  BuildContext context, {
  MetricDefinition? def,
}) {
  final AppScheme c = context.scheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: c.ink.withValues(alpha: 0.30),
    builder: (BuildContext _) => _MetricEditorSheet(def: def),
  );
}

/// 数据项管理：列表 + 新增入口。
Future<void> showMetricManageSheet(BuildContext context) {
  final AppScheme c = context.scheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: c.ink.withValues(alpha: 0.30),
    builder: (BuildContext _) => const _MetricManageSheet(),
  );
}

class _MetricEditorSheet extends ConsumerStatefulWidget {
  const _MetricEditorSheet({this.def});

  final MetricDefinition? def;

  @override
  ConsumerState<_MetricEditorSheet> createState() => _MetricEditorSheetState();
}

class _MetricEditorSheetState extends ConsumerState<_MetricEditorSheet> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.def?.name ?? '');
  late final TextEditingController _unitCtrl =
      TextEditingController(text: widget.def?.unit ?? '');
  late final TextEditingController _targetCtrl = TextEditingController(
    text: widget.def?.targetValue == null
        ? ''
        : trimNumber(widget.def!.targetValue!),
  );

  late MetricValueType _type = widget.def?.valueType ?? MetricValueType.number;
  late int _colorHex = widget.def?.colorHex ?? MetricPalette.values.first;
  late bool _archived = widget.def?.isArchived ?? false;

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.def != null;
  bool get _isBuiltin => widget.def?.isBuiltin ?? false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '给它起个名字吧');
      return;
    }
    final String targetText = _targetCtrl.text.trim();
    final double? target =
        targetText.isEmpty ? null : double.tryParse(targetText);
    if (targetText.isNotEmpty && target == null) {
      setState(() => _error = '目标值要填数字');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final MetricActions actions = ref.read(metricActionsProvider);
    final String unit =
        _type == MetricValueType.clock ? '' : _unitCtrl.text.trim();

    if (_isEdit) {
      await actions.update(
        id: widget.def!.id,
        name: name,
        unit: unit,
        colorHex: _colorHex,
        targetValue: target,
        clearTarget: target == null,
      );
      if (_archived != widget.def!.isArchived) {
        if (_archived) {
          await actions.archive(widget.def!.id);
        } else {
          await actions.unarchive(widget.def!.id);
        }
      }
    } else {
      await actions.addCustom(
        name: name,
        valueType: _type,
        unit: unit,
        colorHex: _colorHex,
        targetValue: target,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final NavigatorState navigator = Navigator.of(context);
    final MetricDefinition def = widget.def!;
    await ref.read(metricActionsProvider).remove(def.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
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
                              _isEdit ? '编辑数据项' : '新增数据项',
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
                          controller: _nameCtrl,
                          hint: '想记录什么？例如「喝水量」',
                          errorText: _error,
                        ),
                        const SizedBox(height: 18),
                        const SheetLabel('类型'),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            for (final MetricValueType t
                                in MetricValueType.values)
                              ...<Widget>[
                                Expanded(
                                  child: SheetChoice(
                                    label: t.label,
                                    color: Color(_colorHex),
                                    selected: _type == t,
                                    onTap: () => setState(() {
                                      _type = t;
                                      _error = null;
                                    }),
                                  ),
                                ),
                                if (t != MetricValueType.values.last)
                                  const SizedBox(width: 10),
                              ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          switch (_type) {
                            MetricValueType.number => '普通数值，例如热量 kcal、体重 kg',
                            MetricValueType.duration => '时长，按分钟记录，图表自动换算成小时',
                            MetricValueType.clock => '时间点，例如 23:30 入睡',
                          },
                          style: TextStyle(
                            fontSize: 11.5,
                            color: c.inkFaint,
                          ),
                        ),
                        if (_type != MetricValueType.clock) ...<Widget>[
                          const SizedBox(height: 18),
                          const SheetLabel('单位（可选）'),
                          const SizedBox(height: 8),
                          SheetField(
                            controller: _unitCtrl,
                            hint: _type == MetricValueType.duration
                                ? '默认「分钟」'
                                : '例如 kcal / 次 / 页',
                          ),
                        ],
                        const SizedBox(height: 18),
                        const SheetLabel('目标值（可选，用来算达标率）'),
                        const SizedBox(height: 8),
                        SheetField(
                          controller: _targetCtrl,
                          hint: _type == MetricValueType.clock
                              ? '例如 1410 代表 23:30'
                              : '例如 180',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const SheetLabel('颜色'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            for (final int hex in MetricPalette.values)
                              _ColorDot(
                                color: Color(hex),
                                selected: _colorHex == hex,
                                onTap: () =>
                                    setState(() => _colorHex = hex),
                              ),
                          ],
                        ),
                        if (_isEdit) ...<Widget>[
                          const SizedBox(height: 20),
                          const Divider(height: 1, thickness: 0.8),
                          const SizedBox(height: 16),
                          _ManageActions(
                            isBuiltin: _isBuiltin,
                            archived: _archived,
                            onArchiveChanged: (bool v) =>
                                setState(() => _archived = v),
                            onDelete: _saving ? null : _delete,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
                  child: GradientButton(
                    label: _saving ? '保存中…' : '保存',
                    icon: Icons.check_rounded,
                    gradient: c.metrics,
                    onPressed: _saving ? null : _save,
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

/// 编辑态底部的归档 / 删除操作。
class _ManageActions extends StatelessWidget {
  const _ManageActions({
    required this.isBuiltin,
    required this.archived,
    required this.onArchiveChanged,
    this.onDelete,
  });

  final bool isBuiltin;
  final bool archived;
  final ValueChanged<bool> onArchiveChanged;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '归档',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    archived ? '已归档：不出现在录入与图表里，历史数据保留' : '归档后不再出现在录入与图表里',
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
              value: archived,
              activeThumbColor: c.indigo,
              onChanged: onArchiveChanged,
            ),
          ],
        ),
        if (isBuiltin)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '内置数据项不支持删除，只能归档。',
              style: TextStyle(fontSize: 11.5, color: c.inkFaint),
            ),
          )
        else
          BounceTap(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  '删除这个数据项（连同历史记录）',
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
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return BounceTap(
      onTap: onTap,
      haptic: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.ink : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: -3,
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

/// 管理列表：所有数据项 + 新增入口。
class _MetricManageSheet extends ConsumerWidget {
  const _MetricManageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScheme c = context.scheme;
    final List<MetricDefinition> defs =
        ref.watch(metricDefinitionsProvider).valueOrNull ??
            const <MetricDefinition>[];
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxHeight = mq.size.height * 0.86;

    return Container(
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
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
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
                          '管理数据项',
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
                  const SizedBox(height: 4),
                  Text(
                    '共 ${defs.length} 项 · 点一项可以改名、设目标值或归档',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
                children: <Widget>[
                  for (final MetricDefinition def in defs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BounceTap(
                        onTap: () =>
                            showMetricEditorSheet(context, def: def),
                        haptic: false,
                        scale: 0.99,
                        child: SoftCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: <Widget>[
                              MetricIconBadge(
                                iconKey: def.iconKey,
                                color: Color(def.colorHex),
                                size: 36,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Flexible(
                                          child: Text(
                                            def.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                              color: c.ink,
                                            ),
                                          ),
                                        ),
                                        if (def.isBuiltin) ...<Widget>[
                                          const SizedBox(width: 6),
                                          MetricTag(
                                            text: '内置',
                                            color: c.inkFaint,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      metricMetaText(
                                        typeLabel: def.valueType.label,
                                        unit: def.unit,
                                        target: def.targetValue,
                                        lowerIsBetter:
                                            metricLowerIsBetter(def),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.edit_rounded,
                                size: 17,
                                color: c.inkFaint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  BounceTap(
                    onTap: () => showMetricEditorSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: c.indigo.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: c.indigo.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: c.indigo,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '新增数据项',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
