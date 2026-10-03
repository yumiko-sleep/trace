import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'ai_cancellation.dart';
import 'ai_config.dart';
import 'ai_provider.dart';
/// OpenAI 兼容协议实现：DeepSeek / 智谱 GLM / OpenAI / 任意自建服务。
///
/// 三个实际的健壮性处理（都是踩过的坑）：
/// 1. **推理模型**：DeepSeek 系列推理模型把思考写在 `reasoning_content`，
///    正文 `content` 可能是空的，而且 `finish_reason` 会是 `length`——
///    这两种情况要分开提示，不能笼统报「空内容」。
/// 2. **400 自动降级**：有些模型不接受 `response_format` / `temperature` 等可选参数，
///    遇到 400 就自动去掉这些可选参数重试一次，避免用户被迫研究参数兼容性。
/// 3. **错误翻译**：401/402/404/422/429/5xx、超时、DNS、权限被拒等
///    全部翻成能直接对症的中文，并保留服务商原始原因。
class OpenAiCompatibleProvider implements AiProvider {
  OpenAiCompatibleProvider(
    this.config, {
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final AiConfig config;

  /// 每个请求都开一个独立客户端：这样才能单独断开某一次请求（取消）。
  final http.Client Function() _clientFactory;

  @override
  String get vendorId => config.vendorId;

  @override
  String get displayName => config.vendorName;

  @override
  bool get supportsJsonMode => true;

  @override
  Future<AiChatResult> complete(
    AiChatRequest request, {
    AiCancellationToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    if (!config.isReady) {
      throw AiProviderException(
        config.hasKey ? '还没填模型名或接口地址' : '还没填 API Key',
      );
    }

    try {
      return await _post(request, optionalParams: true, cancel: cancel);
    } on AiProviderException catch (first) {
      // 400 往往是「这个模型不认某个可选参数」，去掉 response_format / temperature
      // / max_tokens 再试一次；还是失败就把第一次（信息更具体）的错误抛出去。
      if (first.statusCode != 400) rethrow;
      cancel?.throwIfCancelled();
      try {
        return await _post(request, optionalParams: false, cancel: cancel);
      } on AiProviderException {
        throw first;
      }
    }
  }

  Future<AiChatResult> _post(
    AiChatRequest request, {
    required bool optionalParams,
    AiCancellationToken? cancel,
  }) async {
    final Uri uri = Uri.parse(config.chatEndpoint);
    final Map<String, Object?> body = <String, Object?>{
      'model': request.model,
      'messages': request.messages
          .map((AiMessage m) => m.toJson())
          .toList(growable: false),
      'stream': false,
      if (optionalParams && request.temperature > 0)
        'temperature': request.temperature,
      if (optionalParams && request.maxTokens != null)
        'max_tokens': request.maxTokens,
      if (optionalParams && request.jsonMode && supportsJsonMode)
        'response_format': <String, String>{'type': 'json_object'},
    };

    final Stopwatch watch = Stopwatch()..start();

    // 每个请求一个独立客户端：取消 = 关掉它直接断开连接
    final http.Client client = _clientFactory();
    cancel?.onCancel(client.close);

    http.Response response;
    try {
      response = await client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${config.apiKey.trim()}',
            },
            body: jsonEncode(body),
          )
          .timeout(request.timeout);
    } on TimeoutException {
      throw AiProviderException(
        '请求超时（${request.timeout.inSeconds} 秒）。推理模型会思考较久，'
        '可以稍后重试，或在设置里换一个更快的模型。',
      );
    } on http.ClientException catch (e) {
      // 取消导致的断开不是错误
      cancel?.throwIfCancelled();
      throw _networkException(e.message);
    } on SocketException catch (e) {
      cancel?.throwIfCancelled();
      throw _networkException(e.message);
    } catch (e) {
      cancel?.throwIfCancelled();
      throw _networkException('$e');
    } finally {
      client.close();
    }
    watch.stop();

    cancel?.throwIfCancelled();

    final String rawBody = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode != 200) {
      throw AiProviderException(
        _friendlyStatusMessage(response.statusCode),
        statusCode: response.statusCode,
        detail: _extractErrorMessage(rawBody),
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (_) {
      throw AiProviderException(
        '返回内容不是合法 JSON，可能被网关拦截了。',
        detail: _truncate(rawBody),
      );
    }

    final Object? choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AiProviderException(
        '返回里没有 choices 字段，接口地址可能不对（要以 /v1 结尾）。',
        detail: _truncate(rawBody),
      );
    }

    final Map<String, dynamic> choice = choices.first as Map<String, dynamic>;
    final Object? message = choice['message'];
    final Map<String, dynamic> messageMap =
        message is Map<String, dynamic> ? message : <String, dynamic>{};

    final String content =
        messageMap['content'] is String ? (messageMap['content'] as String) : '';
    final String reasoning = messageMap['reasoning_content'] is String
        ? messageMap['reasoning_content'] as String
        : '';
    final String? finishReason =
        choice['finish_reason'] is String ? choice['finish_reason'] as String : null;

    final Object? usage = json['usage'];
    final AiChatResult result = AiChatResult(
      content: content,
      reasoningContent: reasoning.isEmpty ? null : reasoning,
      finishReason: finishReason,
      model: json['model'] as String? ?? request.model,
      promptTokens:
          usage is Map<String, dynamic> ? usage['prompt_tokens'] as int? : null,
      completionTokens: usage is Map<String, dynamic>
          ? usage['completion_tokens'] as int?
          : null,
      latency: watch.elapsed,
    );

    // 正文和思考都空 → 才算真的失败，并且分情况说明原因
    if (!result.hasContent && !result.hasReasoning) {
      throw AiProviderException(
        result.isTruncated
            ? '输出被完全截断（finish_reason=length）：额度太少，'
                '推理模型的思考过程就把它用完了。'
            : '模型返回了空内容，稍后重试或换一个模型。',
        detail: _truncate(rawBody),
      );
    }

    return result;
  }

  /// 连接层异常 → 尽量翻译成能直接对症的中文提示，并保留原始原因。
  AiProviderException _networkException(String raw) {
    final String lower = raw.toLowerCase();
    final String message;
    if (lower.contains('eacces') || lower.contains('permission denied')) {
      message = 'App 没有联网权限，系统直接拒绝了这次请求。'
          '（Android 需要在 AndroidManifest 里声明 INTERNET 权限）';
    } else if (lower.contains('failed host lookup') ||
        lower.contains('nodename nor servname') ||
        lower.contains('unknownhost')) {
      message = '域名解析失败（DNS）：接口地址可能写错了，或当前网络拦截了该域名。';
    } else if (lower.contains('connection refused') ||
        lower.contains('connection reset')) {
      message = '连接被拒绝/中断：接口地址或端口可能不对，也可能是网络中间设备拦截。';
    } else if (lower.contains('handshake') || lower.contains('certificate')) {
      message = 'HTTPS 握手失败：证书校验没过，检查一下接口地址。';
    } else {
      message = '网络连接失败，检查一下手机网络或接口地址。';
    }
    return AiProviderException(message, detail: raw);
  }

  String _friendlyStatusMessage(int status) => switch (status) {
        400 => '请求被拒绝（400）：可能是模型名不对，或这个模型不支持某些参数。',
        401 => 'API Key 无效或已过期（401），去设置里检查一下。',
        402 => '账户余额不足（402），先去服务商后台充值。',
        403 => '没有访问权限（403）：这个 Key 不能调用该模型。',
        404 => '接口地址不存在（404），检查 baseUrl 是否写错。',
        422 => '参数错误（422），检查模型名是否拼对。',
        429 => '触发限流（429）：请求太频繁或额度用尽，稍后再试。',
        500 || 502 || 503 || 504 => '服务商暂时不可用（$status），稍后重试。',
        _ => '请求失败（HTTP $status）。',
      };

  /// 尽量从错误响应里挖出服务商给的原因。
  String? _extractErrorMessage(String rawBody) {
    try {
      final Object? decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final Object? message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return _truncate(message);
          }
        }
        final Object? message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _truncate(message);
        }
      }
    } catch (_) {
      // 忽略：直接退回原始文本
    }
    return _truncate(rawBody);
  }

  String? _truncate(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= 300 ? trimmed : '${trimmed.substring(0, 300)}…';
  }
}
