import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dao/ai_review_dao.dart';
import '../dao/diary_dao.dart';
import '../dao/goal_dao.dart';
import '../dao/journal_dao.dart';
import '../dao/metric_dao.dart';
import '../dao/settings_dao.dart';
import '../dao/task_dao.dart';
import '../db/app_database.dart';
import '../db/connection.dart';
import '../repositories/ai_review_repository.dart';
import '../repositories/diary_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/journal_repository.dart';
import '../repositories/metric_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/task_repository.dart';

/// ============================================================
/// 数据层的依赖注入（Riverpod）。
///
/// UI 层只 `ref.watch(xxxRepositoryProvider)`，
/// 不关心底下是 DAO 还是数据库，方便以后替换实现或写测试替身。
/// ============================================================

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (ref) {
    final AppDatabase db = AppDatabase(openAppConnection());
    ref.onDispose(db.close);
    return db;
  },
);

final Provider<TaskRepository> taskRepositoryProvider =
    Provider<TaskRepository>(
  (ref) => TaskRepository(TaskDao(ref.watch(appDatabaseProvider))),
);

final Provider<GoalRepository> goalRepositoryProvider =
    Provider<GoalRepository>(
  (ref) => GoalRepository(GoalDao(ref.watch(appDatabaseProvider))),
);

final Provider<DiaryRepository> diaryRepositoryProvider =
    Provider<DiaryRepository>(
  (ref) => DiaryRepository(DiaryDao(ref.watch(appDatabaseProvider))),
);

final Provider<MetricRepository> metricRepositoryProvider =
    Provider<MetricRepository>(
  (ref) => MetricRepository(MetricDao(ref.watch(appDatabaseProvider))),
);

final Provider<JournalRepository> journalRepositoryProvider =
    Provider<JournalRepository>(
  (ref) => JournalRepository(JournalDao(ref.watch(appDatabaseProvider))),
);

final Provider<AiReviewRepository> aiReviewRepositoryProvider =
    Provider<AiReviewRepository>(
  (ref) => AiReviewRepository(AiReviewDao(ref.watch(appDatabaseProvider))),
);

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
  (ref) => SettingsRepository(SettingsDao(ref.watch(appDatabaseProvider))),
);
