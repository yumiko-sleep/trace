import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API Key 的存储抽象。
///
/// 生产环境用系统安全存储（Android Keystore / iOS Keychain / Windows DPAPI），
/// 测试用内存实现，避免在单元测试里碰平台通道。
abstract class AiKeyStore {
  Future<String?> read(String vendorId);

  Future<void> write(String vendorId, String apiKey);

  Future<void> delete(String vendorId);
}

/// 真机上的实现。
class SecureAiKeyStore implements AiKeyStore {
  SecureAiKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// 每个服务商一个 key，切换服务商时不会互相覆盖。
  static String storageKey(String vendorId) => 'trace_ai_api_key_$vendorId';

  @override
  Future<String?> read(String vendorId) async {
    try {
      return await _storage.read(key: storageKey(vendorId));
    } catch (_) {
      // 安全存储不可用（极少数机型）时按「未配置」处理，不阻塞整个页面
      return null;
    }
  }

  @override
  Future<void> write(String vendorId, String apiKey) =>
      _storage.write(key: storageKey(vendorId), value: apiKey);

  @override
  Future<void> delete(String vendorId) =>
      _storage.delete(key: storageKey(vendorId));
}

/// 测试与预览用的内存实现。
class InMemoryAiKeyStore implements AiKeyStore {
  InMemoryAiKeyStore([Map<String, String>? initial])
      : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> read(String vendorId) async => _values[vendorId];

  @override
  Future<void> write(String vendorId, String apiKey) async {
    _values[vendorId] = apiKey;
  }

  @override
  Future<void> delete(String vendorId) async {
    _values.remove(vendorId);
  }
}
