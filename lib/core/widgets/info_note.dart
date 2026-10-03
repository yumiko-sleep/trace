import 'package:flutter/material.dart';

import '../theme/app_scheme.dart';
import '../theme/app_theme.dart';

/// 提示条：用于说明、隐私提示等。
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.mint.withValues(alpha: c.isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.mint.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: c.mintDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: c.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
