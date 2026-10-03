import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 打开「这次发给模型的数据」查看器（透明化，便于自查与调试）。
Future<void> showAiSnapshotSheet(
  BuildContext context, {
  required String json,
  String subtitle = '',
}) {
  return showAppSheet<void>(
    context: context,
    barrierAlpha: 0.35,
    builder: (BuildContext _) =>
        _SnapshotSheet(json: json, subtitle: subtitle),
  );
}

class _SnapshotSheet extends StatelessWidget {
  const _SnapshotSheet({required this.json, required this.subtitle});

  final String json;
  final String subtitle;

  String get _pretty {
    final String raw = json.trim();
    if (raw.isEmpty) return '（这条记录没有保存快照）';
    try {
      final Object? decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
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
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '发给模型的数据',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle.trim().isEmpty
                                  ? '这就是模型看到的全部内容，没有任何隐藏字段'
                                  : subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      BounceTap(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: _pretty));
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: c.inkFaint,
                          ),
                        ),
                      ),
                      BounceTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: c.inkFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bgBottom.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.line),
                  ),
                  child: SelectableText(
                    _pretty,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.55,
                      fontFamily: 'monospace',
                      color: c.inkSoft,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
