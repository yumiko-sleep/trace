import 'package:flutter/material.dart';

import '../theme/app_scheme.dart';
import '../theme/app_theme.dart';

/// 一排圆角标签（用于展示子板块 / 数据项等）。
class ChipsRow extends StatelessWidget {
  const ChipsRow({super.key, required this.items, this.dense = false});

  final List<String> items;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (String e) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 12 : 14,
                vertical: dense ? 7 : 9,
              ),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.line),
              ),
              child: Text(
                e,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.inkSoft,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
