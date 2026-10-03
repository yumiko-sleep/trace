import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../providers/theme_providers.dart';

/// 设置页的「外观主题」卡：亮度模式 + 品牌配色 + 实时预览。
///
/// 两套配色（薄荷绿蓝 / 樱花粉白）× 三种亮度（跟随系统 / 浅色 / 深色）
/// 共 6 种组合，改动立即全局生效并存进设置表。
class ThemeSettingsCard extends ConsumerWidget {
  const ThemeSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeSettings settings =
        ref.watch(appThemeSettingsProvider).valueOrNull ??
            AppThemeSettings.fallback;
    final AppScheme c = context.scheme;
    final ThemeActions actions = ref.read(themeActionsProvider);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: c.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '外观主题',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '改完立刻生效，不用重启',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ---------- 亮度模式 ----------
          _Label('亮度', color: c.inkFaint),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final (ThemeMode mode, String label, IconData icon) item
                  in <(ThemeMode, String, IconData)>[
                (ThemeMode.system, '跟随系统', Icons.brightness_auto_rounded),
                (ThemeMode.light, '浅色', Icons.light_mode_rounded),
                (ThemeMode.dark, '深色', Icons.dark_mode_rounded),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: item.$1 == ThemeMode.dark ? 0 : 10,
                    ),
                    child: _ModeButton(
                      label: item.$2,
                      icon: item.$3,
                      selected: settings.mode == item.$1,
                      onTap: () => actions.setMode(item.$1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // ---------- 配色方案 ----------
          _Label('配色方案', color: c.inkFaint),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final AppColorFamily family in AppColorFamily.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: family == AppColorFamily.values.last ? 0 : 10,
                    ),
                    child: _FamilyOption(
                      family: family,
                      // 预览色带跟随当前亮度，深色模式下也能看出实效果
                      preview: family.of(c.brightness),
                      selected: settings.family == family,
                      onTap: () => actions.setFamily(family),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: c.line),
          const SizedBox(height: 16),

          // ---------- 实时预览 ----------
          _Label('当前效果预览（${c.label}）', color: c.inkFaint),
          const SizedBox(height: 10),
          _Preview(scheme: c),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? c.mint.withValues(alpha: c.isDark ? 0.20 : 0.12)
              : c.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.mint.withValues(alpha: 0.55) : c.line,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 17,
              color: selected ? c.mintDeep : c.inkFaint,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? c.mintDeep : c.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyOption extends StatelessWidget {
  const _FamilyOption({
    required this.family,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final AppColorFamily family;
  final AppScheme preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

    return BounceTap(
      onTap: onTap,
      haptic: false,
      scale: 0.97,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: c.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c.mint.withValues(alpha: 0.65) : c.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 色带：直接展示这套配色的头部渐变
            Container(
              height: 26,
              decoration: BoxDecoration(
                gradient: preview.header,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    family.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.mintDeep : c.ink,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 16, color: c.mintDeep),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              family.description,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: c.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 用当前配色画一张迷你预览，直观感受文字对比度与强调色。
class _Preview extends StatelessWidget {
  const _Preview({required this.scheme});

  final AppScheme scheme;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: c.page,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (final Color dot in <Color>[
                  c.mint,
                  c.cyan,
                  c.sky,
                  c.indigo,
                  c.violet,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  c.isDark ? '深色' : '浅色',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '标题示例 · 今日任务',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '正文示例：用来看这套配色的对比度够不够，'
              '深色底下长时间看会不会累。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: c.inkSoft,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: <Widget>[
                  Container(height: 7, color: c.line),
                  FractionallySizedBox(
                    widthFactor: 0.62,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(gradient: c.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: c.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Text(
                    '主按钮',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.mint.withValues(alpha: c.isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '标签',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.mintDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
