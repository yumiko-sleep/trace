import 'package:http/http.dart' as http;

import 'ai_config.dart';
import 'ai_provider.dart';
import 'openai_compatible_provider.dart';

/// ============================================================
/// 服务商注册表：把「配置」变成「可用的 Provider」。
///
/// 新增一个不兼容 OpenAI 协议的服务商时，只在这里加一行分支，
/// 复盘流程（AiReviewController）不需要任何改动。
/// ============================================================
class AiProviderFactory {
  AiProviderFactory({
    http.Client? client,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ??
            (client == null ? http.Client.new : () => client);

  /// 每个请求一个客户端（换取「能单独取消某次请求」的能力）。
  final http.Client Function() _clientFactory;

  AiProvider create(AiConfig config) {
    switch (config.vendorId) {
      case 'deepseek':
      case 'zhipu':
      case 'openai':
      case 'custom':
        return OpenAiCompatibleProvider(config, clientFactory: _clientFactory);
      default:
        // 未知 id（例如以后新增但还没写实现的）也退回兼容实现
        return OpenAiCompatibleProvider(config, clientFactory: _clientFactory);
    }
  }
}
