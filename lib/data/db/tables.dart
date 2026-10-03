import 'package:drift/drift.dart';

import '../models/enums.dart';

/// ============================================================
/// 全部 10 张表定义（阶段 1）
///
/// 约定：
/// - 所有"日期"字段存本地时间；表示"某一天"时统一归一化到当天 00:00。
/// - 枚举一律用 intEnum 存整数。
/// - 外键带 onDelete: cascade，删除主记录时子记录自动清理
///   （SQLite 需要 PRAGMA foreign_keys = ON，已在 AppDatabase.beforeOpen 打开）。
/// ============================================================

/// ---------- 1. 今日任务 ----------
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// 归属日期（通常是今天）
  DateTimeColumn get dueDate => dateTime().nullable()();

  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get doneAt => dateTime().nullable()();

  /// 关联的目标（可空）
  IntColumn get goalId =>
      integer().nullable().references(Goals, #id, onDelete: KeyAction.setNull)();

  /// 0 = 低，1 = 中，2 = 高
  IntColumn get priority => integer().withDefault(const Constant(1))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// ---------- 2. 目标（今日 / 今年 / 人生） ----------
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();

  IntColumn get category => intEnum<GoalCategory>()();

  /// 进度 0.0 ~ 1.0
  RealColumn get progress => real().withDefault(const Constant(0))();

  DateTimeColumn get deadline => dateTime().nullable()();

  IntColumn get status => intEnum<GoalStatus>().withDefault(const Constant(0))();

  /// 上级目标（人生目标 → 今年目标 → 今日目标）
  IntColumn get parentId =>
      integer().nullable().references(Goals, #id, onDelete: KeyAction.setNull)();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// ---------- 3. 日记 ----------
class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 当天 00:00
  DateTimeColumn get date => dateTime()();

  TextColumn get content => text().withDefault(const Constant(''))();

  /// 心情（可空）
  IntColumn get mood => intEnum<Mood>().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 日记图片（一条日记多张图）
class DiaryImages extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get entryId =>
      integer().references(DiaryEntries, #id, onDelete: KeyAction.cascade)();

  /// 图片在 App 私有目录中的相对/绝对路径
  TextColumn get path => text()();

  TextColumn get caption => text().withDefault(const Constant(''))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ---------- 4. 数据（可扩展的数据项定义） ----------
class MetricDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 稳定标识：内置项用固定 key（如 sleep_time），自定义项用生成的 uuid
  TextColumn get key => text().unique()();

  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get unit => text().withDefault(const Constant(''))();

  IntColumn get valueType => intEnum<MetricValueType>()();

  /// ARGB 颜色，用于图表与卡片
  IntColumn get colorHex => integer().withDefault(const Constant(0xFF3DDC97))();

  /// 图标标识（由 UI 层映射成 IconData）
  TextColumn get iconKey => text().withDefault(const Constant(''))();

  /// 目标值（可空），用于达标率统计
  RealColumn get targetValue => real().nullable()();

  /// 是否内置（内置项不允许删除，只能归档）
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 每天每个数据项一条记录
class MetricRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get metricId =>
      integer().references(MetricDefinitions, #id, onDelete: KeyAction.cascade)();

  /// 当天 00:00
  DateTimeColumn get date => dateTime()();

  RealColumn get value => real()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 同一天同一个数据项只能有一条
  @override
  List<Set<Column<Object>>> get uniqueKeys =>
      <Set<Column<Object>>>[
        <Column<Object>>{metricId, date},
      ];
}

/// ---------- 5. 日志（学习 / 训练） ----------
class JournalPlans extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get type => intEnum<JournalType>()();

  TextColumn get title => text().withLength(min: 1, max: 100)();

  /// 计划正文（自由编辑，支持多行）
  TextColumn get content => text().withDefault(const Constant(''))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class JournalLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get type => intEnum<JournalType>()();

  /// 当天 00:00
  DateTimeColumn get date => dateTime()();

  IntColumn get planId =>
      integer().nullable().references(JournalPlans, #id, onDelete: KeyAction.setNull)();

  /// 今日实际做了什么
  TextColumn get content => text().withDefault(const Constant(''))();

  /// 学习 / 训练时长（分钟，可空）
  IntColumn get durationMinutes => integer().nullable()();

  /// 当日复盘总结
  TextColumn get review => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// ---------- 6. AI 复盘 ----------
class AiReviews extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 当天 00:00
  DateTimeColumn get date => dateTime()();

  /// 例如 'zhipu' / 'gemini'
  TextColumn get provider => text().withDefault(const Constant(''))();

  TextColumn get model => text().withDefault(const Constant(''))();

  /// 模型生成的复盘正文
  TextColumn get content => text().withDefault(const Constant(''))();

  IntColumn get status => intEnum<AiReviewStatus>()();

  TextColumn get errorMessage => text().withDefault(const Constant(''))();

  /// 发送给模型的上下文快照（JSON），便于回溯"当时它看到了什么"
  TextColumn get snapshotJson => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ---------- 7. 应用设置（键值对） ----------
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}
