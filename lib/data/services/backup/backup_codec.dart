import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import 'trace_backup.dart';

/// 数据库 ⇄ 备份数据。
///
/// 序列化直接用 drift 给每张表生成的 `toJson()` / `fromJson()`：
/// - 枚举写成整数（和库里的存储一致）
/// - DateTime 写成 Unix 毫秒
/// - 可空字段写成 null
///
/// 好处是「导出 → 导入」走的是 drift 官方支持的往返，不用手工维护
/// 10 张表的字段映射；以后加字段只要重跑 build_runner，备份结构自动跟上。
class BackupCodec {
  const BackupCodec();

  /// 读出全部 10 张表，组装成一份备份数据。
  Future<TraceBackup> dump(AppDatabase db, {required String appVersion}) async {
    final Map<String, List<Map<String, dynamic>>> rows =
        <String, List<Map<String, dynamic>>>{};
    for (final String table in BackupTables.ordered) {
      rows[table] = await _dumpTable(db, table);
    }
    return TraceBackup(
      rows: rows,
      exportedAt: DateTime.now(),
      appVersion: appVersion,
    );
  }

  /// 清空全部表，再写入 [backup]。
  ///
  /// 整个过程在一个事务里：任何一步失败都会整体回滚，不会留下「导了一半」的库。
  /// [resolveImagePath] 把备份里的配图文件名拼成当前设备上的绝对路径。
  Future<void> restore(
    AppDatabase db,
    TraceBackup backup, {
    String Function(String fileName)? resolveImagePath,
  }) async {
    // SQLite 在事务里会忽略这个 PRAGMA，所以必须在开事务**之前**关掉。
    // 关外键是为了能按「行」的顺序写入（父目标可能排在子目标后面、
    // 任务的 goalId 也可能先写进来），写完立刻恢复成 ON——级联删除靠它。
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction(() async {
        await _clearAll(db);
        for (final String table in BackupTables.ordered) {
          final List<Map<String, dynamic>> rows =
              backup.rows[table] ?? const <Map<String, dynamic>>[];
          for (int i = 0; i < rows.length; i++) {
            try {
              await _insertRow(
                db,
                table,
                _withImagePath(table, rows[i], resolveImagePath),
              );
            } catch (e) {
              throw BackupFormatException(
                '${BackupTables.labels[table] ?? table} 第 ${i + 1} 行导入失败：$e',
              );
            }
          }
        }
      });
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  // ---------------- 读 ----------------

  Future<List<Map<String, dynamic>>> _dumpTable(
    AppDatabase db,
    String table,
  ) async {
    switch (table) {
      case BackupTables.goals:
        return _toJson(await db.select(db.goals).get());
      case BackupTables.tasks:
        return _toJson(await db.select(db.tasks).get());
      case BackupTables.diaryEntries:
        return _toJson(await db.select(db.diaryEntries).get());
      case BackupTables.diaryImages:
        return _toJson(await db.select(db.diaryImages).get())
            .map(_stripImagePath)
            .toList();
      case BackupTables.metricDefinitions:
        return _toJson(await db.select(db.metricDefinitions).get());
      case BackupTables.metricRecords:
        return _toJson(await db.select(db.metricRecords).get());
      case BackupTables.journalPlans:
        return _toJson(await db.select(db.journalPlans).get());
      case BackupTables.journalLogs:
        return _toJson(await db.select(db.journalLogs).get());
      case BackupTables.aiReviews:
        return _toJson(await db.select(db.aiReviews).get());
      case BackupTables.appSettings:
        return _toJson(await db.select(db.appSettings).get());
      default:
        return const <Map<String, dynamic>>[];
    }
  }

  static List<Map<String, dynamic>> _toJson(List<DataClass> rows) =>
      <Map<String, dynamic>>[
        for (final DataClass row in rows) row.toJson(),
      ];

  /// 配图只留文件名：绝对路径换机 / 重装后就失效了。
  static Map<String, dynamic> _stripImagePath(Map<String, dynamic> row) {
    final Object? path = row['path'];
    if (path is! String || path.isEmpty) return row;
    return <String, dynamic>{...row, 'path': _baseName(path)};
  }

  /// 兼容 `/` 与 `\` 两种分隔符（备份可能是在桌面端调试时生成的）。
  static String _baseName(String path) => path.split(RegExp(r'[/\\]')).last;

  // ---------------- 写 ----------------

  static Map<String, dynamic> _withImagePath(
    String table,
    Map<String, dynamic> row,
    String Function(String fileName)? resolve,
  ) {
    if (table != BackupTables.diaryImages || resolve == null) return row;
    final Object? path = row['path'];
    if (path is! String || path.isEmpty) return row;
    return <String, dynamic>{...row, 'path': resolve(path)};
  }

  /// 清空全部表。先删子表再删父表，读起来更符合直觉
  /// （此刻外键本来是关的，顺序不影响结果）。
  Future<void> _clearAll(AppDatabase db) async {
    await db.delete(db.diaryImages).go();
    await db.delete(db.metricRecords).go();
    await db.delete(db.journalLogs).go();
    await db.delete(db.tasks).go();
    await db.delete(db.diaryEntries).go();
    await db.delete(db.metricDefinitions).go();
    await db.delete(db.journalPlans).go();
    await db.delete(db.aiReviews).go();
    await db.delete(db.goals).go();
    await db.delete(db.appSettings).go();
  }

  /// 写入一行，保留原始主键（外键引用靠它）。
  ///
  /// 用 `insertOrReplace` 而不是 `insert`：备份里若有重复主键（文件被人改过），
  /// 也不会因为唯一约束直接崩，后写的覆盖先写的。
  Future<void> _insertRow(
    AppDatabase db,
    String table,
    Map<String, dynamic> row,
  ) {
    switch (table) {
      case BackupTables.goals:
        return db.into(db.goals).insert(
              Goal.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.tasks:
        return db.into(db.tasks).insert(
              Task.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.diaryEntries:
        return db.into(db.diaryEntries).insert(
              DiaryEntry.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.diaryImages:
        return db.into(db.diaryImages).insert(
              DiaryImage.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.metricDefinitions:
        return db.into(db.metricDefinitions).insert(
              MetricDefinition.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.metricRecords:
        return db.into(db.metricRecords).insert(
              MetricRecord.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.journalPlans:
        return db.into(db.journalPlans).insert(
              JournalPlan.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.journalLogs:
        return db.into(db.journalLogs).insert(
              JournalLog.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.aiReviews:
        return db.into(db.aiReviews).insert(
              AiReview.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      case BackupTables.appSettings:
        return db.into(db.appSettings).insert(
              AppSetting.fromJson(row).toCompanion(false),
              mode: InsertMode.insertOrReplace,
            );
      default:
        return Future<void>.value();
    }
  }
}
