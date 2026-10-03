import '../dao/settings_dao.dart';

/// 设置项的 key 常量，避免代码里散落魔法字符串。
class SettingsKeys {
  const SettingsKeys._();

  static const String themeMode = 'theme_mode';

  /// 品牌配色方案：mint / sakura
  static const String colorScheme = 'color_scheme';
  static const String aiProvider = 'ai_provider';
  static const String aiModel = 'ai_model';
  static const String aiBaseUrl = 'ai_base_url';
  static const String aiAutoReviewEnabled = 'ai_auto_review_enabled';
  static const String aiAutoReviewHour = 'ai_auto_review_hour';
  static const String firstLaunchAt = 'first_launch_at';
  static const String seededVersion = 'seeded_version';
}

/// 设置仓储。
///
/// 注意：这里只存**非敏感**配置。
/// API Key 这类机密信息走 flutter_secure_storage（阶段 7 接入），不进数据库。
class SettingsRepository {
  SettingsRepository(this._dao);

  final SettingsDao _dao;

  Future<Map<String, String>> getAll() => _dao.getAll();

  Future<String?> getString(String key) => _dao.get(key);

  Stream<String?> watchString(String key) => _dao.watch(key);

  Future<void> setString(String key, String value) => _dao.set(key, value);

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final String? raw = await _dao.get(key);
    if (raw == null) return defaultValue;
    return raw == 'true' || raw == '1';
  }

  Future<void> setBool(String key, bool value) =>
      _dao.set(key, value ? 'true' : 'false');

  Future<int?> getInt(String key) async {
    final String? raw = await _dao.get(key);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setInt(String key, int value) => _dao.set(key, '$value');

  Future<int> remove(String key) => _dao.delete(key);

  Future<void> clear() => _dao.deleteAll();

  // ---------------- 外观主题 ----------------

  /// system / light / dark（存字符串，不把 Material 类型渗到数据层）
  Future<String> get themeModeId async =>
      await _dao.get(SettingsKeys.themeMode) ?? 'system';

  Future<void> setThemeModeId(String id) => _dao.set(SettingsKeys.themeMode, id);

  /// mint / sakura
  Future<String> get colorFamilyId async =>
      await _dao.get(SettingsKeys.colorScheme) ?? 'mint';

  Future<void> setColorFamilyId(String id) =>
      _dao.set(SettingsKeys.colorScheme, id);

  // ---------------- 常用配置的语义化封装 ----------------

  Future<String> get aiProvider async =>
      await _dao.get(SettingsKeys.aiProvider) ?? 'deepseek';

  Future<void> setAiProvider(String provider) =>
      _dao.set(SettingsKeys.aiProvider, provider);

  /// 默认模型：用户要求以 DeepSeek-V4-Pro 作为推理模型。
  Future<String> get aiModel async =>
      await _dao.get(SettingsKeys.aiModel) ?? 'deepseek-v4-pro';

  Future<void> setAiModel(String model) =>
      _dao.set(SettingsKeys.aiModel, model);

  /// 自定义接口地址；空字符串表示用服务商预设的地址。
  Future<String> get aiBaseUrl async =>
      await _dao.get(SettingsKeys.aiBaseUrl) ?? '';

  Future<void> setAiBaseUrl(String baseUrl) =>
      _dao.set(SettingsKeys.aiBaseUrl, baseUrl);

  Future<bool> get autoReviewEnabled =>
      getBool(SettingsKeys.aiAutoReviewEnabled);

  Future<void> setAutoReviewEnabled(bool enabled) =>
      setBool(SettingsKeys.aiAutoReviewEnabled, enabled);

  /// 记录首次启动时间（只在第一次写入）。
  Future<void> markFirstLaunchIfNeeded() async {
    final String? existing = await _dao.get(SettingsKeys.firstLaunchAt);
    if (existing == null) {
      await _dao.set(
        SettingsKeys.firstLaunchAt,
        DateTime.now().toIso8601String(),
      );
    }
  }
}
