import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../models/enums.dart';
import '../seed/built_in_metrics.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// 应用数据库。
///
/// - 正式运行：[AppDatabase] + [openAppConnection]（落盘到 App 私有目录）
/// - 单元测试：[AppDatabase.memory]（纯内存，跑完即销毁）
@DriftDatabase(
  tables: <Type>[
    Tasks,
    Goals,
    DiaryEntries,
    DiaryImages,
    MetricDefinitions,
    MetricRecords,
    JournalPlans,
    JournalLogs,
    AiReviews,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 内存数据库，供单元测试使用。
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          // SQLite 默认不启用外键约束，必须显式打开（否则级联删除不生效）
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) {
            await _seedBuiltInMetrics();
          }
        },
      );

  /// 写入 5 个内置数据项。用 insertOrIgnore 保证幂等，重复执行不会产生重复行。
  Future<void> _seedBuiltInMetrics() async {
    await batch((Batch b) {
      b.insertAll(
        metricDefinitions,
        kBuiltInMetrics
            .map(
              (BuiltInMetric m) => MetricDefinitionsCompanion.insert(
                key: m.key,
                name: m.name,
                valueType: m.valueType,
                unit: Value(m.unit),
                colorHex: Value(m.colorHex),
                iconKey: Value(m.iconKey),
                targetValue: Value(m.targetValue),
                isBuiltin: const Value<bool>(true),
                sortOrder: Value(m.sortOrder),
              ),
            )
            .toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// 手动补种（例如用户误删了内置项，或后续新增内置项时调用）。
  Future<void> ensureBuiltInMetrics() => _seedBuiltInMetrics();
}
