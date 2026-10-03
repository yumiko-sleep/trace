import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trace/data/services/ai/ai_cancellation.dart';
import 'package:trace/data/services/ai/ai_config.dart';
import 'package:trace/data/services/ai/ai_provider.dart';
import 'package:trace/data/services/ai/ai_provider_factory.dart';

void main() {
  AiConfig config({
    String vendorId = 'deepseek',
    String model = 'deepseek-v4-pro',
    String apiKey = 'sk-test-1234567890abcd',
    String baseUrl = 'https://api.deepseek.com/v1',
  }) =>
      AiConfig(
        vendorId: vendorId,
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
      );

  /// 带 UTF-8 声明构造响应：http 包默认按 latin1 编码字符串响应体，
  /// 直接传中文会报 “Contains invalid characters”。
  http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );

  AiChatRequest request({Duration timeout = const Duration(seconds: 5)}) =>
      AiChatRequest(
        model: 'deepseek-v4-pro',
        jsonMode: true,
        timeout: timeout,
        messages: const <AiMessage>[
          AiMessage.system('你是复盘助手'),
          AiMessage.user('{"a":1}'),
        ],
      );

  group('AiConfig', () {
    test('默认预设是 DeepSeek + deepseek-v4-pro', () {
      expect(kAiVendors.first.id, 'deepseek');
      expect(kAiVendors.first.defaultModel, 'deepseek-v4-pro');
      expect(aiVendorById('不存在').id, 'deepseek', reason: '未知 id 回退到默认预设');
    });

    test('请求地址拼接与尾部斜杠处理', () {
      expect(
        config().chatEndpoint,
        'https://api.deepseek.com/v1/chat/completions',
      );
      expect(
        config(baseUrl: 'https://x.com/v1/').chatEndpoint,
        'https://x.com/v1/chat/completions',
      );
    });

    test('Key 脱敏与就绪判断', () {
      expect(config().maskedKey, 'sk-tes…abcd');
      expect(config(apiKey: '').maskedKey, '未配置');
      expect(config(apiKey: '').isReady, isFalse);
      expect(config().isReady, isTrue);
      expect(config(model: '').isReady, isFalse);
    });
  });

  group('OpenAiCompatibleProvider', () {
    test('成功：解析 content / usage，并带上 response_format', () async {
      http.Request? captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'model': 'deepseek-v4-pro',
            'choices': <Map<String, dynamic>>[
              <String, dynamic>{
                'message': <String, dynamic>{'content': '{"headline":"不错的一天"}'},
              },
            ],
            'usage': <String, dynamic>{
              'prompt_tokens': 1200,
              'completion_tokens': 180,
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final AiProvider provider =
          AiProviderFactory(client: client).create(config());
      final AiChatResult result = await provider.complete(request());

      expect(result.content, '{"headline":"不错的一天"}');
      expect(result.promptTokens, 1200);
      expect(result.completionTokens, 180);
      expect(result.totalTokens, 1380);

      final Map<String, dynamic> body =
          jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['model'], 'deepseek-v4-pro');
      expect(body['stream'], false);
      expect(
        body['response_format'],
        <String, String>{'type': 'json_object'},
      );
      expect(
        (body['messages'] as List<dynamic>).length,
        2,
        reason: 'system + user 两条',
      );
      expect(
        captured!.headers['Authorization'],
        'Bearer sk-test-1234567890abcd',
      );
      expect(
        captured!.url.toString(),
        'https://api.deepseek.com/v1/chat/completions',
      );
    });

    test('401：给出可读提示 + 服务商原始原因', () async {
      final MockClient client = MockClient(
        (http.Request _) async => http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{'message': 'Invalid API key provided'},
          }),
          401,
        ),
      );

      expect(
        AiProviderFactory(client: client).create(config()).complete(request()),
        throwsA(
          isA<AiProviderException>()
              .having((AiProviderException e) => e.isAuthError, 'isAuthError', true)
              .having(
                (AiProviderException e) => e.message,
                'message',
                contains('API Key'),
              )
              .having(
                (AiProviderException e) => e.detail,
                'detail',
                contains('Invalid API key'),
              ),
        ),
      );
    });

    test('429 / 500 分类正确', () async {
      Future<Object> call(int status) async {
        final MockClient client = MockClient(
          (http.Request _) async => http.Response('{"error":"boom"}', status),
        );
        try {
          await AiProviderFactory(client: client).create(config()).complete(request());
          return 'no-error';
        } catch (e) {
          return e;
        }
      }

      final Object limited = await call(429);
      expect(limited, isA<AiProviderException>());
      expect((limited as AiProviderException).isRateLimited, isTrue);

      final Object server = await call(503);
      expect(server, isA<AiProviderException>());
      expect((server as AiProviderException).isServerError, isTrue);

      final Object notFound = await call(404);
      expect((notFound as AiProviderException).message, contains('baseUrl'));
    });

    test('没有 Key 时直接报错，不发请求', () async {
      bool called = false;
      final MockClient client = MockClient((http.Request _) async {
        called = true;
        return http.Response('{}', 200);
      });

      await expectLater(
        AiProviderFactory(client: client)
            .create(config(apiKey: ''))
            .complete(request()),
        throwsA(isA<AiProviderException>()),
      );
      expect(called, isFalse);
    });

    test('网络异常翻译成中文提示，并保留底层原因', () async {
      final MockClient client = MockClient(
        (http.Request _) async => throw http.ClientException('SocketException'),
      );

      await expectLater(
        AiProviderFactory(client: client).create(config()).complete(request()),
        throwsA(
          isA<AiProviderException>()
              .having((AiProviderException e) => e.isNetworkError, 'isNetworkError', true)
              .having(
                (AiProviderException e) => e.message,
                'message',
                contains('网络'),
              )
              .having(
                (AiProviderException e) => e.detail,
                'detail',
                contains('SocketException'),
              ),
        ),
      );
    });

    test('权限被拒（release 包缺 INTERNET 权限）会单独提示', () async {
      final MockClient client = MockClient(
        (http.Request _) async => throw http.ClientException(
          'SocketException: socket failed: EACCES (Permission denied)',
        ),
      );

      await expectLater(
        AiProviderFactory(client: client).create(config()).complete(request()),
        throwsA(
          isA<AiProviderException>()
              .having(
                (AiProviderException e) => e.message,
                'message',
                contains('联网权限'),
              )
              .having(
                (AiProviderException e) => e.detail,
                'detail',
                contains('EACCES'),
              ),
        ),
      );
    });

    test('DNS 解析失败单独提示', () async {
      final MockClient client = MockClient(
        (http.Request _) async => throw http.ClientException(
          'Failed host lookup: \'api.deepseek.com\'',
        ),
      );

      await expectLater(
        AiProviderFactory(client: client).create(config()).complete(request()),
        throwsA(
          isA<AiProviderException>().having(
            (AiProviderException e) => e.message,
            'message',
            contains('域名解析失败'),
          ),
        ),
      );
    });

    test('返回不是 JSON / 缺 choices 都报错', () async {
      final MockClient badJson = MockClient(
        (http.Request _) async => http.Response('<html>401</html>', 200),
      );
      await expectLater(
        AiProviderFactory(client: badJson).create(config()).complete(request()),
        throwsA(isA<AiProviderException>()),
      );

      final MockClient noChoices = MockClient(
        (http.Request _) async =>
            http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200),
      );
      await expectLater(
        AiProviderFactory(client: noChoices).create(config()).complete(request()),
        throwsA(
          isA<AiProviderException>().having(
            (AiProviderException e) => e.message,
            'message',
            contains('choices'),
          ),
        ),
      );
    });

    test('推理模型：正文为空但 reasoning_content 有内容不算失败', () async {
      final MockClient client = MockClient(
        (http.Request _) async => jsonResponse(<String, dynamic>{
          'model': 'deepseek-v4-pro',
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'finish_reason': 'length',
              'message': <String, dynamic>{
                'role': 'assistant',
                'content': '',
                'reasoning_content': '我们需要回答用户…',
              },
            },
          ],
        }),
      );

      final AiChatResult result =
          await AiProviderFactory(client: client).create(config()).complete(request());
      expect(result.content, isEmpty);
      expect(result.hasContent, isFalse);
      expect(result.reasoningContent, '我们需要回答用户…');
      expect(result.hasReasoning, isTrue);
      expect(result.finishReason, 'length');
      expect(result.isTruncated, isTrue);
    });

    test('正文与思考全空且被截断 → 提示额度不够', () async {
      final MockClient client = MockClient(
        (http.Request _) async => jsonResponse(<String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'finish_reason': 'length',
              'message': <String, dynamic>{'content': ''},
            },
          ],
        }),
      );

      await expectLater(
        AiProviderFactory(client: client).create(config()).complete(request()),
        throwsA(
          isA<AiProviderException>().having(
            (AiProviderException e) => e.message,
            'message',
            contains('截断'),
          ),
        ),
      );
    });

    test('遇到 400 会自动去掉可选参数重试一次', () async {
      final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
      final MockClient client = MockClient((http.Request req) async {
        final Map<String, dynamic> body =
            jsonDecode(req.body) as Map<String, dynamic>;
        bodies.add(body);
        if (bodies.length == 1) {
          return jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'message': 'response_format is not supported by this model',
            },
          }, 400);
        }
        return jsonResponse(<String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'finish_reason': 'stop',
              'message': <String, dynamic>{'content': '{"headline":"ok"}'},
            },
          ],
        });
      });

      final AiChatResult result =
          await AiProviderFactory(client: client).create(config()).complete(request());

      expect(result.content, '{"headline":"ok"}');
      expect(bodies.length, 2, reason: '第一次 400 → 自动重试一次');
      expect(bodies.first.containsKey('response_format'), isTrue);
      expect(bodies.last.containsKey('response_format'), isFalse);
      expect(bodies.last.containsKey('temperature'), isFalse);
      expect(bodies.last.containsKey('max_tokens'), isFalse);
    });

    test('已取消的令牌：连请求都不发', () async {
      bool called = false;
      final MockClient client = MockClient((http.Request _) async {
        called = true;
        return jsonResponse(<String, dynamic>{});
      });
      final AiCancellationToken token = AiCancellationToken()..cancel();

      await expectLater(
        AiProviderFactory(clientFactory: () => client)
            .create(config())
            .complete(request(), cancel: token),
        throwsA(isA<AiCancelledException>()),
      );
      expect(called, isFalse);
    });

    test('请求进行中取消 → 抛 AiCancelledException，不当成网络错误', () async {
      final MockClient client = MockClient((http.Request _) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return jsonResponse(<String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'message': <String, dynamic>{'content': 'x'},
            },
          ],
        });
      });
      final AiCancellationToken token = AiCancellationToken();

      final Future<AiChatResult> future =
          AiProviderFactory(clientFactory: () => client)
              .create(config())
              .complete(request(), cancel: token);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();

      await expectLater(future, throwsA(isA<AiCancelledException>()));
    });

    test('超时给出可读提示', () async {
      final MockClient client = MockClient((http.Request _) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200);
      });

      await expectLater(
        AiProviderFactory(client: client).create(config()).complete(
              request(timeout: const Duration(milliseconds: 30)),
            ),
        throwsA(
          isA<AiProviderException>().having(
            (AiProviderException e) => e.message,
            'message',
            contains('超时'),
          ),
        ),
      );
    });
  });
}
