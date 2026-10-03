import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_scheme.dart';
import '../../../data/providers/data_providers.dart';

/// 当前的外观设置：亮度模式 + 品牌配色方案。
@immutable
class AppThemeSettings {
  const AppThemeSettings({required this.mode, required this.family});

  final ThemeMode mode;
  final AppColorFamily family;

  /// 读取完成前的兜底：跟随系统 + 默认配色
  static const AppThemeSettings fallback = AppThemeSettings(
    mode: ThemeMode.system,
    family: AppColorFamily.mint,
  );

  AppThemeSettings copyWith({ThemeMode? mode, AppColorFamily? family}) =>
      AppThemeSettings(
        mode: mode ?? this.mode,
        family: family ?? this.family,
      );
}

/// 从设置表读出来的外观配置（改动后 invalidate 即可全局生效）。
final FutureProvider<AppThemeSettings> appThemeSettingsProvider =
    FutureProvider<AppThemeSettings>((Ref ref) async {
  final String modeId = await ref.watch(settingsRepositoryProvider).themeModeId;
  final String familyId =
      await ref.watch(settingsRepositoryProvider).colorFamilyId;
  return AppThemeSettings(
    mode: switch (modeId) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    family: appColorFamilyFromId(familyId),
  );
});

final Provider<ThemeActions> themeActionsProvider =
    Provider<ThemeActions>((Ref ref) => ThemeActions(ref));

class ThemeActions {
  ThemeActions(this._ref);

  final Ref _ref;

  Future<void> setMode(ThemeMode mode) async {
    await _ref.read(settingsRepositoryProvider).setThemeModeId(
          switch (mode) {
            ThemeMode.light => 'light',
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
          },
        );
    _ref.invalidate(appThemeSettingsProvider);
  }

  Future<void> setFamily(AppColorFamily family) async {
    await _ref.read(settingsRepositoryProvider).setColorFamilyId(family.id);
    _ref.invalidate(appThemeSettingsProvider);
  }
}
