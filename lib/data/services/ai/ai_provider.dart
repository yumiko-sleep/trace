/// ============================================================
/// AI Provider 抽象层（只放接口与数据模型，具体实现见同目录其他文件）。
///
/// 上层（复盘流程）只认这三个东西：
///   1. [AiProvider] 接口
///   2. [AiChatRequest] / [AiChatResult] 输入输出模型
///   3. [AiProviderException] 统一错误
///
/// 想接入不兼容 OpenAI 协议的服务商（Gemini / Claude），
/// 只要再写一个 `implements AiProvider` 的类，在
/// `AiProviderFactory.create` 里注册一行即可，复盘流程完全不用改。
/// ============================================================
library;

import 'ai_cancellation.dart';

enum AiRole { system, user }

class AiMessage {
  const AiMessage(this.role, this.content);

  const AiMessage.system(String content) : this(AiRole.system, content);

  const AiMessage.user(String content) : this(AiRole.user, content);

  final AiRole role;
  final String content;

  String get roleName => role == AiRole.system ? 'system' : 'user';

  Map<String, String> toJson() => <String, String>{
        'role': roleName,
        'content': content,
      };
}

/// 一次对话补全请求。
class AiChatRequest {
  const AiChatRequest({
    required this.messages,
    required this.model,
    this.temperature = 0.4,
    this.maxTokens,
    this.jsonMode = false,
    this.timeout = const Duration(seconds: 120),
  });

  final List<AiMessage> messages;
  final String model;
  final double temperature;
  final int? maxTokens;

  /// 是否要求模型返回严格 JSON（服务商支持时才会带上 response_format）。
  final bool jsonMode;

  final Duration timeout;
}

/// 一次对话补全结果。
class AiChatResult {
  const AiChatResult({
    required this.content,
    required this.model,
    this.reasoningContent,
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
    this.latency = Duration.zero,
  });

  /// 正文（`choices[0].message.content`）。
  final String content;

  /// 推理模型的思考过程（`choices[0].message.reasoning_content`）。
  ///
  /// DeepSeek 系列推理模型会把思考写在这里，正文可能是空的，
  /// 所以「取不到正文」时要看它，而不是直接当失败。
  final String? reasoningContent;

  /// `choices[0].finish_reason`：`stop` / `length` / `content_filter`…
  final String? finishReason;

  final String model;
  final int? promptTokens;
  final int? completionTokens;
  final Duration latency;

  /// 输出是否因为额度用完被截断。
  bool get isTruncated => finishReason == 'length';

  bool get hasContent => content.trim().isNotEmpty;

  bool get hasReasoning =>
      (reasoningContent ?? '').trim().isNotEmpty;

  int? get totalTokens => promptTokens == null && completionTokens == null
      ? null
      : (promptTokens ?? 0) + (completionTokens ?? 0);
}

/// 统一错误：带上 HTTP 状态码，方便界面给出可读的中文提示。
class AiProviderException implements Exception {
  const AiProviderException(
    this.message, {
    this.statusCode,
    this.detail,
  });

  /// 已经翻译好的中文提示，可直接展示给用户。
  final String message;
  final int? statusCode;

  /// 服务商返回的原始信息（截断后展示在「详情」里）。
  final String? detail;

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  bool get isRateLimited => statusCode == 429;

  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// 网络层错误（没有状态码）。
  bool get isNetworkError => statusCode == null;

  @override
  String toString() =>
      'AiProviderException(${statusCode ?? '-'}): $message'
      '${detail == null ? '' : ' | $detail'}';
}

/// Provider 抽象。
abstract class AiProvider {
  /// 对应服务商预设 id（deepseek / zhipu / openai / custom）
  String get vendorId;

  String get displayName;

  /// 是否支持 `response_format: {"type":"json_object"}`
  bool get supportsJsonMode;

  /// 发起一次补全。[cancel] 可用时，取消会真实断开连接。
  Future<AiChatResult> complete(
    AiChatRequest request, {
    AiCancellationToken? cancel,
  });
}
