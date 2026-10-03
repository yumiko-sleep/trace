import 'dart:convert';
import 'dart:typed_data';

/// ============================================================
/// 备份文件的结构（阶段 8⑤：导出 / 导入数据）
///
/// 一个备份 = 一个 zip：
/// ```
/// trace_backup_20261003_1624.zip
/// ├── data.json        10 张表的全部内容
/// └── images/xxx.jpg   日记配图本体
/// ```
///
/// 为什么配图只存文件名：绝对路径里带着安装信息
/// （`/data/user/0/<包名>/…`），换机或重装后会变；
/// 而文件名是我们自己按时间戳生成的、不会重名，
/// 恢复时拼回当前设备的私有目录即可。
///
/// 为什么备份里没有 API Key：Key 存在系统安全存储
/// （Android Keystore）里，根本不进数据库，也不该明文写进备份文件。
/// ============================================================

/// 备份格式版本。以后结构有不兼容改动时升到 v2，并在解析处做兼容判断。
const String kTraceBackupSchema = 'trace.backup.v1';

/// 压缩包里数据文件的固定名字。
const String kBackupDataEntry = 'data.json';

/// 压缩包里配图所在目录。
const String kBackupImagesDir = 'images';

/// 备份文件本身有问题：不是 zip、缺 data.json、版本不认识、结构坏了。
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 备份涉及的 10 张表：JSON 里的键名、恢复时的写入顺序、中文名。
class BackupTables {
  const BackupTables._();

  static const String goals = 'goals';
  static const String tasks = 'tasks';
  static const String diaryEntries = 'diary_entries';
  static const String diaryImages = 'diary_images';
  static const String metricDefinitions = 'metric_definitions';
  static const String metricRecords = 'metric_records';
  static const String journalPlans = 'journal_plans';
  static const String journalLogs = 'journal_logs';
  static const String aiReviews = 'ai_reviews';
  static const String appSettings = 'app_settings';

  /// 恢复时按这个顺序写入：被引用的表排在前面
  /// （恢复期间外键是关掉的，所以顺序只是「好看 + 稳」）。
  static const List<String> ordered = <String>[
    goals,
    tasks,
    diaryEntries,
    diaryImages,
    metricDefinitions,
    metricRecords,
    journalPlans,
    journalLogs,
    aiReviews,
    appSettings,
  ];

  /// 弹窗里给人看的名字。
  static const Map<String, String> labels = <String, String>{
    goals: '目标',
    tasks: '任务',
    diaryEntries: '日记',
    diaryImages: '配图',
    metricDefinitions: '数据项',
    metricRecords: '数据记录',
    journalPlans: '计划',
    journalLogs: '日志',
    aiReviews: 'AI 复盘',
    appSettings: '设置',
  };
}

/// 一份备份的**数据部分**（不含图片文件本体，图片由 service 打包）。
class TraceBackup {
  const TraceBackup({
    required this.rows,
    this.exportedAt,
    this.appVersion = '',
  });

  /// 表名（见 [BackupTables]）→ 行列表。
  ///
  /// 每行的键与 drift 生成的 `toJson()` / `fromJson()` 完全一致：
  /// 枚举存整数、时间存 Unix 毫秒、可空字段存 null。
  final Map<String, List<Map<String, dynamic>>> rows;

  /// 导出时间；老备份或手工改过的文件可能没有。
  final DateTime? exportedAt;

  /// 导出时的 App 版本，只用于回溯。
  final String appVersion;

  int countOf(String table) => rows[table]?.length ?? 0;

  /// 只列出非空的表，免得弹窗里一堆 0。
  Map<String, int> get counts => <String, int>{
        for (final MapEntry<String, List<Map<String, dynamic>>> entry
            in rows.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.length,
      };

  int get totalRows => rows.values
      .fold(0, (int sum, List<Map<String, dynamic>> r) => sum + r.length);

  int get imageCount => countOf(BackupTables.diaryImages);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': kTraceBackupSchema,
        'exportedAt': exportedAt?.millisecondsSinceEpoch,
        'appVersion': appVersion,
        'counts': counts,
        'data': rows,
      };

  /// 序列化成 UTF-8 的 JSON 字节（zip 里 data.json 的内容）。
  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// 从 data.json 的字节还原；结构不对时抛 [BackupFormatException]。
  static TraceBackup decode(List<int> bytes) {
    final Object? json = _decodeJson(bytes);
    if (json is! Map) {
      throw const BackupFormatException('备份数据的顶层结构不对（应该是一个 JSON 对象）');
    }
    return TraceBackup.fromJson(json.cast<String, dynamic>());
  }

  factory TraceBackup.fromJson(Map<String, dynamic> json) {
    final Object? schema = json['schema'];
    if (schema != kTraceBackupSchema) {
      throw BackupFormatException(
        '这不是「轨迹 Trace」的备份文件（格式标记：${schema ?? '缺失'}）',
      );
    }

    final Object? raw = json['data'];
    if (raw is! Map) {
      throw const BackupFormatException('备份文件里没有数据段（data）');
    }

    final Map<String, List<Map<String, dynamic>>> rows =
        <String, List<Map<String, dynamic>>>{};
    raw.forEach((dynamic key, dynamic value) {
      if (value is! List) return;
      rows['$key'] = <Map<String, dynamic>>[
        for (final dynamic row in value)
          if (row is Map) row.cast<String, dynamic>(),
      ];
    });

    return TraceBackup(
      rows: rows,
      exportedAt: _parseDate(json['exportedAt']),
      appVersion: '${json['appVersion'] ?? ''}',
    );
  }

  static Object? _decodeJson(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw BackupFormatException('备份里的 $kBackupDataEntry 不是合法的 JSON：${e.message}');
    }
  }

  static DateTime? _parseDate(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
