import 'package:flutter/material.dart';

import 'soft_card.dart';
import '../../core/theme/app_scheme.dart';
import '../../core/theme/app_theme.dart';

/// 模块规划卡：告诉用户这个板块现在到哪一步了。
class RoadmapCard extends StatelessWidget {
  const RoadmapCard({
    super.key,
    required this.phase,
    required this.items,
    this.title = '本模块规划',
  });

  final String phase;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final TextTheme t = Theme.of(context).textTheme;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title, style: t.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: c.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  phase,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (String it) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Text(it, style: t.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
