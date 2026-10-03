import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/day_utils.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/stats.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/journal_repository.dart';
import '../../../data/repositories/metric_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/services/ai/ai_cancellation.dart';
import '../../../data/services/ai/ai_config.dart';
import '../../../data/services/ai/ai_key_store.dart';
import '../../../data/services/ai/ai_provider.dart';
import '../../../data/services/ai/ai_provider_factory.dart';
import '../domain/ai_review_context.dart';
import '../domain/ai_review_prompts.dart';
import '../domain/ai_review_report.dart';

/// ============================================================
/// AI 复盘的状态与操作。
/// ============================================================

/// API Key 的安全存储（测试里 override 成 [InMemoryAiKeyStore]）。
final Provider<AiKeyStore> aiKeyStoreProvider =
    Provider<AiKeyStore>((Ref ref) => SecureAiKeyStore());

/// 服务商工厂（测试里 override 成返回假 Provider 的工厂）。
///
/// 不注入共享 http.Client：每次请求单独开一个客户端，
/// 这样「取消生成」才能真的把这次请求断开。
final Provider<AiProviderFactory> aiProviderFactoryProvider =
    Provider<AiProviderFactory>((Ref ref) => AiProviderFactory());

/// 当前 AI 配置：设置表（供应商 / 模型 / 地址）+ 安全存储（API Key）。
final FutureProvider<AiConfig> aiConfigProvider = FutureProvider<AiConfig>(
  (Ref ref) async {
    final String vendorId =
        await ref.watch(settingsRepositoryProvider).aiProvider;
    final AiVendorPreset preset = aiVendorById(vendorId);
    final String storedModel =
        await ref.watch(settingsRepositoryProvider).aiModel;
    final String storedBaseUrl =
        await ref.watch(settingsRepositoryProvider).aiBaseUrl;
    final String apiKey =
        await ref.watch(aiKeyStoreProvider).read(vendorId) ?? '';

    return AiConfig(
      vendorId: vendorId,
      baseUrl: storedBaseUrl.trim().isEmpty ? preset.baseUrl : storedBaseUrl,
      model: storedModel.trim().isEmpty ? preset.defaultModel : storedModel,
      apiKey: apiKey,
    );
  },
);

/// 历史复盘（新的在前）。
final AutoDisposeStreamProvider<List<AiReview>> aiReviewHistoryProvider =
    StreamProvider.autoDispose<List<AiReview>>(
  (Ref ref) => ref.watch(aiReviewRepositoryProvider).watchAll(),
);

/// 今天的复盘记录（含生成中 / 失败状态）。
final AutoDisposeStreamProvider<AiReview?> todayAiReviewProvider =
    StreamProvider.autoDispose<AiReview?>(
  (Ref ref) => ref
      .watch(aiReviewRepositoryProvider)
      .watchLatestOfDay(DayUtils.dayStart(DateTime.now())),
);

/// 配置的读写操作。
final Provider<AiConfigActions> aiConfigActionsProvider =
    Provider<AiConfigActions>((Ref ref) => AiConfigActions(ref));

class AiConfigActions {
  AiConfigActions(this._ref);

  final Ref _ref;

  /// 保存配置；[apiKey] 为 null 表示不改动已存的 Key。
  Future<void> save({
    required String vendorId,
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    final SettingsRepository settings = _ref.read(settingsRepositoryProvider);
    await settings.setAiProvider(vendorId);
    await settings.setAiBaseUrl(baseUrl.trim());
    await settings.setAiModel(model.trim());
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await _ref.read(aiKeyStoreProvider).write(vendorId, apiKey.trim());
    }
    _ref.invalidate(aiConfigProvider);
  }

  Future<void> clearKey(String vendorId) async {
    await _ref.read(aiKeyStoreProvider).delete(vendorId);
    _ref.invalidate(aiConfigProvider);
  }

  /// 测试连接：发一条极短请求，返回可直接展示的结果。
  ///
  /// 推理模型可能只返回思考过程（content 为空、reasoning_content 有内容），
  /// 这种情况也算连接成功，不然用户会以为自己配置错了。
  Future<String> testConnection() async {
    final AiConfig config = await _ref.read(aiConfigProvider.future);
    if (!config.hasKey) {
      throw const AiProviderException('还没填 API Key');
    }
    final AiProvider provider = _ref.read(aiProviderFactoryProvider).create(config);
    final AiChatResult result = await provider.complete(
      AiChatRequest(
        model: config.model,
        messages: <AiMessage>[AiMessage.user(AiReviewPrompts.ping())],
        temperature: 0,
        // 推理模型要先写思考过程，额度给小了会一个字都输出不出来
        maxTokens: 1024,
        timeout: const Duration(seconds: 60),
      ),
    );

    final String content = result.content.trim();
    if (content.isNotEmpty) return content;

    final String reasoning = (result.reasoningContent ?? '').trim();
    final String snippet = reasoning.length <= 60
        ? reasoning
        : '${reasoning.substring(0, 60)}…';
    return '（推理模型，本次只返回了思考过程）$snippet';
  }
}

/// 采集当天数据 → 结构化 JSON。
class AiReviewDataSource {
  AiReviewDataSource(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> collect(DateTime day) async {
    final DateTime d0 = DayUtils.dayStart(day);
    final DateTime from =
        d0.subtract(const Duration(days: AiReviewContextBuilder.trendDays - 1));

    final TaskRepository taskRepo = _ref.read(taskRepositoryProvider);
    final GoalRepository goalRepo = _ref.read(goalRepositoryProvider);
    final DiaryRepository diaryRepo = _ref.read(diaryRepositoryProvider);
    final MetricRepository metricRepo = _ref.read(metricRepositoryProvider);
    final JournalRepository journalRepo = _ref.read(journalRepositoryProvider);

    // 这几步互不依赖，并行跑，省掉串行等待（每个查询都要过一遍 SQLite）
    final (
      List<Task> tasks,
      List<Goal> goals,
      Map<int, DayTaskStats> goalTaskStats,
      DiaryEntry? diary,
      List<DiaryEntry> allDiary,
      List<MetricDefinition> defs,
      List<List<JournalPlan>> plansByType,
    ) = await (
      taskRepo.getAll(),
      goalRepo.getAll(),
      taskRepo.linkedStatsByGoal(),
      diaryRepo.getByDay(d0),
      diaryRepo.getAll(),
      metricRepo.getDefinitions(),
      Future.wait(
        JournalType.values.map((JournalType t) => journalRepo.getPlans(t)),
      ),
    ).wait;

    final List<JournalPlan> plans =
        plansByType.expand((List<JournalPlan> p) => p).toList();

    final int imageCount =
        diary == null ? 0 : (await diaryRepo.getImages(diary.id)).length;
    final List<DiaryEntry> recentDiary = allDiary
        .where((DiaryEntry e) => !DayUtils.dayStart(e.date).isBefore(from))
        .toList(growable: false);

    // 每个数据项的趋势查询也并行
    final List<List<MetricTrendPoint>> trendLists =
        await Future.wait(<Future<List<MetricTrendPoint>>>[
      for (final MetricDefinition def in defs)
        metricRepo.getTrend(
          def.id,
          days: AiReviewContextBuilder.trendDays,
          end: d0,
        ),
    ]);
    final Map<int, List<MetricTrendPoint>> trends =
        <int, List<MetricTrendPoint>>{
      for (int i = 0; i < defs.length; i++) defs[i].id: trendLists[i],
    };

    final List<List<JournalLog>> logsByType =
        await Future.wait(<Future<List<JournalLog>>>[
      for (final JournalType t in JournalType.values) journalRepo.getLogs(t),
    ]);
    final List<JournalLog> logs =
        logsByType.expand((List<JournalLog> l) => l).toList();
    final List<JournalLog> recentLogs = logs
        .where((JournalLog l) => !DayUtils.dayStart(l.date).isBefore(from))
        .toList(growable: false);

    return AiReviewContextBuilder.build(
      day: d0,
      tasks: tasks,
      goals: goals,
      goalTaskStats: goalTaskStats,
      diary: diary,
      diaryImageCount: imageCount,
      recentDiary: recentDiary,
      metricDefinitions: defs,
      metricTrends: trends,
      journalPlans: plans,
      journalLogs: logs,
      recentJournalLogs: recentLogs,
    );
  }
}

final Provider<AiReviewDataSource> aiReviewDataSourceProvider =
    Provider<AiReviewDataSource>((Ref ref) => AiReviewDataSource(ref));

/// 生成过程的界面状态。
class AiReviewRunState {
  const AiReviewRunState({
    this.running = false,
    this.step = '',
    this.error,
    this.reviewId,
  });

  final bool running;

  /// 当前步骤文案（收集数据 / 请求模型 / 整理结果…）
  final String step;

  final String? error;
  final int? reviewId;

  AiReviewRunState copyWith({
    bool? running,
    String? step,
    String? error,
    bool clearError = false,
    int? reviewId,
  }) =>
      AiReviewRunState(
        running: running ?? this.running,
        step: step ?? this.step,
        error: clearError ? null : (error ?? this.error),
        reviewId: reviewId ?? this.reviewId,
      );
}

/// 生成复盘：收集数据 → 落 pending → 调模型 → 回填结果。
final StateNotifierProvider<AiReviewController, AiReviewRunState>
    aiReviewControllerProvider =
    StateNotifierProvider<AiReviewController, AiReviewRunState>(
  (Ref ref) => AiReviewController(ref),
);

class AiReviewController extends StateNotifier<AiReviewRunState> {
  AiReviewController(this._ref) : super(const AiReviewRunState());

  final Ref _ref;

  /// 当前这次生成的取消令牌（没在生成时为 null）。
  AiCancellationToken? _token;

  /// 用户点「取消」：真实断开正在进行的请求，并把这条记录标成「已取消」。
  void cancel() {
    final AiCancellationToken? token = _token;
    if (token == null) return;
    // 先切回空闲，界面立刻有反馈；后续的收尾由 generate() 的 catch 完成
    state = const AiReviewRunState();
    token.cancel();
  }

  /// 生成（或重新生成）某天的复盘，返回写入的记录 id。
  Future<int?> generate({DateTime? day}) async {
    if (state.running) return null;
    final DateTime d0 = DayUtils.dayStart(day ?? DateTime.now());
    final AiCancellationToken token = AiCancellationToken();
    _token = token;

    AiConfig config;
    try {
      config = await _ref.read(aiConfigProvider.future);
    } catch (e) {
      state = AiReviewRunState(error: '读取 AI 配置失败：$e');
      return null;
    }

    if (!config.hasKey) {
      state = const AiReviewRunState(
        error: '还没有配置 API Key。到「设置 → AI 复盘」里填一个，再回来生成。',
      );
      return null;
    }
    if (!config.isReady) {
      state = const AiReviewRunState(
        error: 'AI 配置不完整：模型名和接口地址都要填。',
      );
      return null;
    }

    try {
      state = const AiReviewRunState(running: true, step: '正在收集今天的数据…');
      final Map<String, dynamic> context =
          await _ref.read(aiReviewDataSourceProvider).collect(d0);
      final String contextJson = AiReviewContextBuilder.encode(context);

      state = state.copyWith(
        step: '正在请求 ${config.vendorName} · ${config.model}，可能要等十几秒…',
      );

      final int reviewId =
          await _ref.read(aiReviewRepositoryProvider).startReview(
                day: d0,
                provider: config.vendorId,
                model: config.model,
                snapshotJson: contextJson,
              );

      try {
        final AiProvider provider =
            _ref.read(aiProviderFactoryProvider).create(config);
        final AiChatResult result = await provider.complete(
          AiChatRequest(
            model: config.model,
            temperature: config.temperature,
            timeout: config.timeout,
            jsonMode: true,
            // 不设 max_tokens：交给服务商自己的默认值，
            // 推理模型的思考过程很吃输出额度，我们管住它反而容易把 JSON 截断。
            messages: <AiMessage>[
              AiMessage.system(AiReviewPrompts.system()),
              AiMessage.user(
                AiReviewPrompts.user(
                  dateText: DayUtils.formatDate(d0),
                  contextJson: contextJson,
                ),
              ),
            ],
          ),
          cancel: token,
        );
        token.throwIfCancelled();

        // 推理模型可能只给思考过程、正文是空的：这种情况要明确告知，
        // 不能把「思考过程」当成复盘正文存下来。
        if (!result.hasContent) {
          final String reasoning = (result.reasoningContent ?? '').trim();
          throw AiProviderException(
            result.isTruncated
                ? '输出被截断（finish_reason=length）：额度不够，'
                    '推理模型的思考过程占满了。可以在设置里换一个非推理模型，或稍后重试。'
                : '模型只返回了思考过程，没有输出正文。推荐换一个非推理模型（例如 deepseek-chat）。',
            detail: reasoning.isEmpty
                ? null
                : '思考过程：${reasoning.length <= 120 ? reasoning : '${reasoning.substring(0, 120)}…'}',
          );
        }

        state = state.copyWith(step: '正在整理复盘报告…');
        final AiReviewReport report =
            AiReviewReport.parse(result.content, model: result.model);
        await _ref.read(aiReviewRepositoryProvider).complete(
              reviewId,
              report.parsed ? report.encode() : result.content,
            );
        state = AiReviewRunState(reviewId: reviewId);
        return reviewId;
      } on AiCancelledException {
        await _ref.read(aiReviewRepositoryProvider).fail(reviewId, '已取消');
        state = const AiReviewRunState();
        return reviewId;
      } on AiProviderException catch (e) {
        final String described = _describe(e);
        await _ref.read(aiReviewRepositoryProvider).fail(reviewId, described);
        state = AiReviewRunState(error: described, reviewId: reviewId);
        return reviewId;
      } catch (e) {
        final String described = '生成失败：$e';
        await _ref.read(aiReviewRepositoryProvider).fail(reviewId, described);
        state = AiReviewRunState(error: described, reviewId: reviewId);
        return reviewId;
      }
    } catch (e) {
      state = AiReviewRunState(error: '准备数据失败：$e');
      return null;
    } finally {
      _token = null;
    }
  }

  /// 把「卡住的」pending 记录标为失败（App 被杀、请求中断）。
  Future<int> cleanStalePending() =>
      _ref.read(aiReviewRepositoryProvider).failStalePending();

  Future<int> remove(AiReview review) =>
      _ref.read(aiReviewRepositoryProvider).remove(review.id);

  /// 撤销删除。
  Future<int> restore(AiReview review) =>
      _ref.read(aiReviewRepositoryProvider).restore(review);

  /// 把友好提示与底层原因拼起来展示，方便定位（例如权限 / DNS / 证书）。
  String _describe(AiProviderException e) {
    final String? detail = e.detail;
    if (detail == null || detail.trim().isEmpty) return e.message;
    return '${e.message}\n（底层原因：${detail.trim()}）';
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// 调试用：看看这次发给模型的 JSON。
  static String prettyContext(Map<String, dynamic> context) =>
      const JsonEncoder.withIndent('  ').convert(context);
}
