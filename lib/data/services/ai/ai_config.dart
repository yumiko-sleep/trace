/// AI 服务商预设与运行时配置。
///
/// 目前所有预设都兼容 OpenAI 的 `POST /chat/completions` 协议，
/// 差别只在 baseUrl / 默认模型；用户可以在设置页把它们全部改掉。
library;

/// 服务商预设。
class AiVendorPreset {
  const AiVendorPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    required this.note,
    this.suggestedModels = const <String>[],
  });

  /// 稳定标识（同时用于安全存储里的 key 命名）
  final String id;
  final String name;

  /// 接口根地址，实际请求 `${baseUrl}/chat/completions`
  final String baseUrl;
  final String defaultModel;
  final String note;

  /// 设置页里的「一键填充」候选（第一个一般是更快的非推理模型）。
  final List<String> suggestedModels;
}

/// 预设列表。第一项是默认服务商。
const List<AiVendorPreset> kAiVendors = <AiVendorPreset>[
  AiVendorPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    defaultModel: 'deepseek-v4-pro',
    note: '国内可直连，默认模型 deepseek-v4-pro',
    suggestedModels: <String>[
      'deepseek-chat',
      'deepseek-v4-pro',
    ],
  ),
  AiVendorPreset(
    id: 'zhipu',
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-4-plus',
    note: '国内可直连；模型名可填 glm-4v 系列',
    suggestedModels: <String>[
      'glm-4-flash',
      'glm-4-plus',
    ],
  ),
  AiVendorPreset(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    note: '需要能访问 api.openai.com',
    suggestedModels: <String>[
      'gpt-4o-mini',
      'gpt-4o',
    ],
  ),
  AiVendorPreset(
    id: 'custom',
    name: '自定义',
    baseUrl: '',
    defaultModel: '',
    note: '任何兼容 /chat/completions 的服务，自己填地址和模型名',
  ),
];

AiVendorPreset aiVendorById(String id) => kAiVendors.firstWhere(
      (AiVendorPreset v) => v.id == id,
      orElse: () => kAiVendors.first,
    );

/// 一次复盘要用的完整配置（设置表 + 安全存储合并后的结果）。
class AiConfig {
  const AiConfig({
    required this.vendorId,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.temperature = 0.4,
    this.timeout = const Duration(seconds: 180),
  });

  final String vendorId;
  final String baseUrl;
  final String model;

  /// 只存在内存里，落盘走 [AiKeyStore]（flutter_secure_storage）。
  final String apiKey;

  final double temperature;
  final Duration timeout;

  AiVendorPreset get vendor => aiVendorById(vendorId);

  String get vendorName => vendor.name;

  bool get hasKey => apiKey.trim().isNotEmpty;

  bool get isReady =>
      hasKey && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  /// 展示用的脱敏 Key：`sk-abcd…wxyz`。
  String get maskedKey {
    final String key = apiKey.trim();
    if (key.isEmpty) return '未配置';
    if (key.length <= 10) return '${key.substring(0, 2)}…';
    return '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
  }

  /// 真正的请求地址。
  String get chatEndpoint =>
      '${baseUrl.trim().replaceAll(RegExp(r'/+$'), '')}/chat/completions';

  AiConfig copyWith({
    String? vendorId,
    String? baseUrl,
    String? model,
    String? apiKey,
    double? temperature,
    Duration? timeout,
  }) =>
      AiConfig(
        vendorId: vendorId ?? this.vendorId,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        temperature: temperature ?? this.temperature,
        timeout: timeout ?? this.timeout,
      );
}
