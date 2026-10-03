import 'package:flutter/material.dart';

import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 主页问候区：按时段问候 + 日期 + 一句自我提醒。
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  static const List<String> _weekdays = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  String _greeting(int hour) {
    if (hour < 6) return '夜深了';
    if (hour < 11) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _formatDate(DateTime d) =>
      '${d.year}年${d.month}月${d.day}日 星期${_weekdays[d.weekday - 1]}';

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final AppScheme c = context.scheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _greeting(now.hour),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 7),
              Text(
                _formatDate(now),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '能拯救你的只有你自己',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.mintDeep,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: c.primary,
            borderRadius: BorderRadius.circular(15),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.cyan.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }
}
