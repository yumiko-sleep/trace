import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_scheme.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'bounce_tap.dart';

/// ============================================================
/// 底部弹窗（BottomSheet）通用的表单小组件。
/// 所有弹窗都用这一套，保证观感、动效与配色完全一致。
/// ============================================================

/// 小节标题。
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: context.scheme.inkFaint,
      ),
    );
  }
}

/// 输入框（自带圆角容器、聚焦描边、错误提示）。
class SheetField extends StatelessWidget {
  const SheetField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.focusNode,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final FocusNode? focusNode;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.bgBottom.withValues(alpha: c.isDark ? 0.55 : 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: errorText == null
              ? c.line
              : c.danger.withValues(alpha: 0.6),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        cursorColor: c.mint,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: c.ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: c.inkFaint,
            fontWeight: FontWeight.w400,
          ),
          errorText: errorText,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// 可选胶囊。`dense = true` 时用于一排「标签」式的多选项。
class SheetChoice extends StatelessWidget {
  const SheetChoice({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return BounceTap(
      onTap: onTap,
      haptic: false,
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 13 : 0,
          vertical: dense ? 8 : 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: c.isDark ? 0.20 : 0.12)
              : c.bgBottom.withValues(alpha: c.isDark ? 0.55 : 0.7),
          borderRadius: BorderRadius.circular(dense ? 999 : 14),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.55) : c.line,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense ? 12.5 : 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? color : c.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}
