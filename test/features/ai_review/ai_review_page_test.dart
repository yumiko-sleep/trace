import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/core/widgets/diary_media.dart' show PillActionButton;
import 'package:trace/data/dao/ai_review_dao.dart';
import 'package:trace/data/dao/settings_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/models/enums.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/data/repositories/ai_review_repository.dart';
import 'package:trace/data/repositories/settings_repository.dart';
import 'package:trace/data/services/ai/ai_cancellation.dart';
import 'package:trace/data/services/ai/ai_config.dart';
import 'package:trace/data/services/ai/ai_key_store.dart';
import 'package:trace/data/services/ai/ai_provider.dart';
import 'package:trace/data/services/ai/ai_provider_factory.dart';
import 'package:trace/features/ai_review/providers/ai_review_providers.dart';

/// 假的 Provider：直接返回准备好的 JSON，不碰网络。
class FakeAiProvider implements AiProvider {
  FakeAiProvider({
    this.content = '',
    this.reasoning,
    this.error,
    this.finishReason,
    this.hang = false,
  });

  final String content;
  final String? reasoning;
  final String? finishReason;
  final AiProviderException? error;

  /// true = 永不返回（除非被取消），用于测试「取消生成」。
  final bool hang;

  AiChatRequest? lastRequest;
  int callCount = 0;

  @override
  String get vendorId => 'deepseek';

  @override
  String get displayName => 'DeepSeek';

  @override
  bool get supportsJsonMode => true;

  @override
  Future<AiChatResult> complete(
    AiChatRequest request, {
    AiCancellationToken? cancel,
  }) async {
    callCount++;
    lastRequest = request;
    if (hang) {
      final Completer<void> completer = Completer<void>();
      cancel?.onCancel(() {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    }
    cancel?.throwIfCancelled();
    if (error != null) throw error!;
    return AiChatResult(
      content: content,
      reasoningContent: reasoning,
      finishReason: finishReason,
      model: request.model,
    );
  }
}

class FakeAiProviderFactory extends AiProviderFactory {
  FakeAiProviderFactory(this.provider);

  final AiProvider provider;

  @override
  AiProvider create(AiConfig config) => provider;
}

void main() {
  late AppDatabase db;
  late AiReviewRepository reviews;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase.memory();
    reviews = AiReviewRepository(AiReviewDao(db));
    settings = SettingsRepository(SettingsDao(db));
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openPage(
    WidgetTester tester, {
    required InMemoryAiKeyStore store,
    AiProvider? provider,
    bool settingsTab = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          aiKeyStoreProvider.overrideWithValue(store),
          if (provider != null)
            aiProviderFactoryProvider
                .overrideWithValue(FakeAiProviderFactory(provider)),
        ],
        child: const TraceApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 底部导航未选中项只显示图标
    await tester.tap(
      find.byIcon(
        settingsTab ? Icons.tune_rounded : Icons.auto_awesome_outlined,
      ),
    );
    await settle(tester, frames: 10);
  }

  Future<void> tapAt(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester, frames: 2);
    await tester.tap(finder);
    await settle(tester, frames: 10);
  }

  testWidgets('没有配置 API Key 时给出明确引导', (WidgetTester tester) async {
    await openPage(tester, store: InMemoryAiKeyStore());

    expect(find.text('还没有配置 API Key'), findsOneWidget);
    expect(find.text('还没有复盘记录'), findsOneWidget);

    await tester.tap(find.byType(PillActionButton));
    await settle(tester, frames: 10);

    expect(
      find.textContaining('还没有配置 API Key。到「设置'),
      findsOneWidget,
    );
    expect(await reviews.getAll(), isEmpty, reason: '没配置时不该写 pending 记录');

    await disposeTree(tester);
  });

  testWidgets('配置好 Key 后能生成结构化复盘，并落库 + 可查快照', (WidgetTester tester) async {
    final InMemoryAiKeyStore store = InMemoryAiKeyStore(
      <String, String>{'deepseek': 'sk-fake-1234567890'},
    );
    final FakeAiProvider provider = FakeAiProvider(
      content: '{"headline":"今天推进得不错，但晚上拖太久",'
          '"good":["完成周报","阅读 25 分钟"],'
          '"improve":["屏幕时间 200 分钟，超目标 20 分钟"],'
          '"tomorrow":["21:30 前收手机","把没做的两件事排到上午"],'
          '"trend_insights":["入睡时间 7 天内从 23:10 推迟到 00:40"]}',
    );

    await openPage(tester, store: store, provider: provider);

    expect(find.text('DeepSeek · deepseek-v4-pro'), findsOneWidget);
    expect(find.text('今天的复盘'), findsOneWidget);

    await tester.tap(find.byType(PillActionButton));
    await settle(tester, frames: 25);

    // 四个分块都在（标题同时出现在结果卡与历史卡里）
    expect(find.text('今天推进得不错，但晚上拖太久'), findsWidgets);
    expect(find.text('今天做得好的'), findsOneWidget);
    expect(find.text('需要改进的'), findsOneWidget);
    expect(find.text('明天建议'), findsOneWidget);
    expect(find.text('数据趋势洞察'), findsOneWidget);
    expect(find.text('21:30 前收手机'), findsOneWidget);

    // 请求里带上了结构化上下文与 JSON 模式
    expect(provider.callCount, 1);
    final AiChatRequest sent = provider.lastRequest!;
    expect(sent.jsonMode, isTrue);
    expect(sent.messages.length, 2);
    expect(sent.messages.first.content, contains('复盘'));
    expect(sent.messages.last.content, contains('"schema": "trace.daily_review.v1"'));
    expect(sent.messages.last.content, contains('"trend_tables"'));

    // 落库为成功
    final List<AiReview> saved = await reviews.getAll();
    expect(saved.length, 1);
    expect(saved.single.status, AiReviewStatus.success);
    expect(saved.single.model, 'deepseek-v4-pro');
    expect(saved.single.provider, 'deepseek');
    expect(saved.single.snapshotJson, contains('daily_review.v1'));

    // 历史列表出现这条
    expect(find.text('历史复盘'), findsOneWidget);

    // 快照查看器
    await tapAt(tester, find.text('查看发给模型的数据'));
    expect(find.text('发给模型的数据'), findsOneWidget);
    expect(find.textContaining('"for_date"'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await settle(tester, frames: 8);

    await disposeTree(tester);
  });

  testWidgets('模型报错时记录失败状态并给出重试入口', (WidgetTester tester) async {
    final InMemoryAiKeyStore store = InMemoryAiKeyStore(
      <String, String>{'deepseek': 'sk-fake-1234567890'},
    );
    final FakeAiProvider provider = FakeAiProvider(
      error: const AiProviderException(
        'API Key 无效或已过期（401），去设置里检查一下。',
        statusCode: 401,
      ),
    );

    await openPage(tester, store: store, provider: provider);
    await tester.tap(find.byType(PillActionButton));
    await settle(tester, frames: 25);

    expect(find.textContaining('API Key 无效或已过期'), findsWidgets);
    expect(find.text('重试'), findsWidgets);

    final List<AiReview> saved = await reviews.getAll();
    expect(saved.length, 1);
    expect(saved.single.status, AiReviewStatus.failed);
    expect(saved.single.errorMessage, contains('API Key 无效'));

    await disposeTree(tester);
  });

  testWidgets('生成过程中可以取消，记录标为已取消', (WidgetTester tester) async {
    final InMemoryAiKeyStore store = InMemoryAiKeyStore(
      <String, String>{'deepseek': 'sk-fake-1234567890'},
    );
    final FakeAiProvider provider = FakeAiProvider(hang: true);

    await openPage(tester, store: store, provider: provider);
    await tester.tap(find.byType(PillActionButton));
    await settle(tester, frames: 12);

    expect(find.text('AI 正在读你的一天'), findsOneWidget);
    expect(find.text('取消生成'), findsOneWidget);

    await tapAt(tester, find.text('取消生成'));
    await settle(tester, frames: 12);

    expect(find.text('AI 正在读你的一天'), findsNothing);
    final List<AiReview> saved = await reviews.getAll();
    expect(saved.length, 1);
    expect(saved.single.status, AiReviewStatus.failed);
    expect(saved.single.errorMessage, '已取消');
    expect(find.text('生成今天的复盘'), findsWidgets, reason: '取消后能再次生成');

    await disposeTree(tester);
  });

  testWidgets('测试连接：推理模型只返回思考过程也算成功', (WidgetTester tester) async {
    final InMemoryAiKeyStore store = InMemoryAiKeyStore(
      <String, String>{'deepseek': 'sk-fake-1234567890'},
    );
    final FakeAiProvider provider = FakeAiProvider(
      content: '',
      reasoning: '我们需要回答用户「请只回复两个字：可用」，所以直接回复「可用」',
      finishReason: 'length',
    );

    await openPage(tester, store: store, provider: provider, settingsTab: true);
    await tapAt(tester, find.text('测试连接'));
    await settle(tester, frames: 12);

    expect(find.textContaining('连接成功'), findsOneWidget);
    expect(find.textContaining('只返回了思考过程'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('设置页可以填 Key 与模型名并保存', (WidgetTester tester) async {
    final InMemoryAiKeyStore store = InMemoryAiKeyStore();

    await openPage(tester, store: store, settingsTab: true);

    expect(find.text('AI 复盘'), findsWidgets);
    expect(find.text('未配置'), findsOneWidget);

    final Finder keyField = find.byType(TextField).first;
    await tester.ensureVisible(keyField);
    await settle(tester, frames: 2);
    await tester.enterText(keyField, 'sk-new-key-abcdefg');
    await settle(tester, frames: 2);

    await tapAt(tester, find.text('保存'));
    await settle(tester, frames: 12);

    expect(store.values['deepseek'], 'sk-new-key-abcdefg');
    expect(await settings.aiProvider, 'deepseek');
    expect(await settings.aiModel, 'deepseek-v4-pro');
    expect(await settings.aiBaseUrl, 'https://api.deepseek.com/v1');
    expect(find.text('已保存'), findsOneWidget);

    // 保存后 Key 不会随配置读回来（只显示脱敏形式）
    expect(find.text('sk-new…defg'), findsOneWidget);

    await disposeTree(tester);
  });
}
