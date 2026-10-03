import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../db/app_database.dart';
import '../image_storage.dart';
import 'backup_codec.dart';
import 'trace_backup.dart';

/// 导出文件名的前缀，方便用户在「文件」App 里一眼认出。
const String kBackupFileNamePrefix = 'trace_backup_';

/// 备份包的扩展名。
const String kBackupFileExtension = 'zip';

/// ============================================================
/// 数据备份 / 恢复（阶段 8⑤）
///
/// 使用场景：换正式签名要先卸载 App，而卸载会清掉 App 私有数据；
/// 先导出一份 zip 存到手机「下载」目录（公共存储，卸载不会动它），
/// 重装后再导入就能完整恢复（含日记配图）。
///
/// 导出走的系统「另存为」和导入走的系统文件选择器都是 Android 的 SAF，
/// **不需要任何存储权限**。
/// ============================================================

/// 需要用户参与的两件事：把字节存到用户选的位置、拿用户选的文件。
///
/// 抽成接口是为了在测试里换成内存版，不弹系统对话框。
abstract class BackupFileGateway {
  /// 返回保存到的位置；用户在系统对话框里取消时返回 null。
  Future<Uri?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  /// 返回用户挑中的备份包（已读成字节）；取消时返回 null。
  Future<PickedBackupFile?> pickBackupFile();
}

/// 用户挑中的备份包。
class PickedBackupFile {
  const PickedBackupFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// 走系统文件选择器（Android 是 SAF）。
class SystemBackupFileGateway implements BackupFileGateway {
  const SystemBackupFileGateway();

  @override
  Future<Uri?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: '选择备份保存位置（建议选「下载」）',
    );
  }

  @override
  Future<PickedBackupFile?> pickBackupFile() async {
    final PlatformFile? file = await FilePicker.pickFile(
      dialogTitle: '选择要导入的备份包',
      type: FileType.custom,
      allowedExtensions: <String>[kBackupFileExtension],
    );
    if (file == null) return null;
    return PickedBackupFile(name: file.name, bytes: await file.readAsBytes());
  }
}

/// 导出结果。[savedTo] 为 null 表示用户在系统对话框里取消了。
class BackupExportResult {
  const BackupExportResult({
    required this.savedTo,
    required this.counts,
    required this.imageCount,
    required this.missingImages,
    required this.bytes,
  });

  final Uri? savedTo;
  final Map<String, int> counts;
  final int imageCount;

  /// 数据库里引用了、但磁盘上找不到的配图数量（备份里会少这几张）
  final int missingImages;
  final int bytes;

  bool get cancelled => savedTo == null;

  int get totalRows => counts.values.fold(0, (int sum, int n) => sum + n);

  String get sizeText => BackupService.formatSize(bytes);
}

/// 已经解析好、等用户确认的备份（配图还在内存里的 [archive] 中）。
class PendingBackup {
  const PendingBackup({
    required this.fileName,
    required this.backup,
    required this.archive,
  });

  final String fileName;
  final TraceBackup backup;
  final Archive archive;

  DateTime? get exportedAt => backup.exportedAt;

  Map<String, int> get counts => backup.counts;

  int get imageCount => backup.imageCount;

  int get totalRows => backup.totalRows;
}

/// 导入结果。
class BackupImportResult {
  const BackupImportResult({
    required this.counts,
    required this.imageCount,
    required this.missingImages,
    this.warnings = const <String>[],
  });

  final Map<String, int> counts;

  /// 成功写回私有目录的配图数量
  final int imageCount;

  /// 备份里引用了、但包里没有的配图数量
  final int missingImages;

  /// 写图片时单个文件失败的说明
  final List<String> warnings;

  int get totalRows => counts.values.fold(0, (int sum, int n) => sum + n);

  int get problemImages => missingImages + warnings.length;
}

/// 「轨迹」的数据备份 / 恢复。
class BackupService {
  BackupService(
    this._db, {
    BackupFileGateway gateway = const SystemBackupFileGateway(),
    BackupCodec codec = const BackupCodec(),
    Future<Directory> Function()? imagesDirectory,
  })  : _gateway = gateway,
        _codec = codec,
        _imagesDirectory = imagesDirectory ?? ImageStorage.directory;

  /// 跟 pubspec.yaml 的 version 保持一致，写进备份里方便回溯。
  static const String appVersion = '0.2.1+1';

  final AppDatabase _db;
  final BackupFileGateway _gateway;
  final BackupCodec _codec;
  final Future<Directory> Function() _imagesDirectory;

  // ---------------- 导出 ----------------

  /// 读全库 → 打成一个 zip（data.json + images/）→ 让用户选保存位置。
  Future<BackupExportResult> export() async {
    final TraceBackup backup = await _codec.dump(_db, appVersion: appVersion);
    final Archive archive = Archive()
      ..add(ArchiveFile.string(kBackupDataEntry, jsonEncode(backup.toJson())));

    final Directory dir = await _imagesDirectory();
    int images = 0;
    int missing = 0;
    for (final Map<String, dynamic> row
        in backup.rows[BackupTables.diaryImages] ?? const <Map<String, dynamic>>[]) {
      final Object? name = row['path'];
      if (name is! String || name.isEmpty) continue;

      final File file = File(p.join(dir.path, name));
      if (!file.existsSync()) {
        missing++;
        continue;
      }
      final Uint8List data = await file.readAsBytes();
      // 配图本来就是压缩过的 jpg/png，再 deflate 一次既慢又几乎不省空间。
      archive.add(
        ArchiveFile.noCompress('$kBackupImagesDir/$name', data.length, data),
      );
      images++;
    }

    final Uint8List bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final Uri? saved = await _gateway.saveBytes(
      fileName: backupFileName(DateTime.now()),
      bytes: bytes,
      mimeType: 'application/zip',
    );

    return BackupExportResult(
      savedTo: saved,
      counts: backup.counts,
      imageCount: images,
      missingImages: missing,
      bytes: bytes.length,
    );
  }

  /// `trace_backup_20261003_1624.zip`
  static String backupFileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '$kBackupFileNamePrefix'
        '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}'
        '.$kBackupFileExtension';
  }

  // ---------------- 导入 ----------------

  /// 让用户挑一个备份包并解析。取消返回 null；文件不对抛 [BackupFormatException]。
  Future<PendingBackup?> pickForImport() async {
    final PickedBackupFile? picked = await _gateway.pickBackupFile();
    if (picked == null) return null;
    return parse(picked);
  }

  /// 解析已经拿到的备份包（单独抽出来，测试可以直接喂字节）。
  PendingBackup parse(PickedBackupFile picked) {
    final Archive archive = _decodeZip(picked.bytes);
    final ArchiveFile? data = archive.find(kBackupDataEntry);
    if (data == null) {
      throw const BackupFormatException(
        '这个压缩包里没有 $kBackupDataEntry，可能选错了文件',
      );
    }
    return PendingBackup(
      fileName: picked.name,
      backup: TraceBackup.decode(data.content),
      archive: archive,
    );
  }

  /// 把配图写回私有目录，再清空数据库全量恢复（事务，失败整体回滚）。
  Future<BackupImportResult> restore(PendingBackup pending) async {
    final Directory dir = await _imagesDirectory();
    if (!dir.existsSync()) await dir.create(recursive: true);

    // 先把图片落盘、再动数据库：万一数据库这步失败回滚了，
    // 最多留下几个没人引用的图片文件（设置页的「配图文件维护」能清掉），
    // 不会出现「日记引用的图不见了」这种更难受的状态。
    int images = 0;
    int missing = 0;
    final List<String> warnings = <String>[];
    for (final Map<String, dynamic> row
        in pending.backup.rows[BackupTables.diaryImages] ?? const <Map<String, dynamic>>[]) {
      final Object? name = row['path'];
      if (name is! String || name.isEmpty) continue;

      final ArchiveFile? entry = pending.archive.find('$kBackupImagesDir/$name');
      if (entry == null) {
        missing++;
        continue;
      }
      try {
        await File(p.join(dir.path, name)).writeAsBytes(
          entry.content,
          flush: true,
        );
        images++;
      } on FileSystemException catch (e) {
        warnings.add('$name：${e.message}');
      }
    }

    await _codec.restore(
      _db,
      pending.backup,
      resolveImagePath: (String name) => p.join(dir.path, name),
    );

    return BackupImportResult(
      counts: pending.backup.counts,
      imageCount: images,
      missingImages: missing,
      warnings: warnings,
    );
  }

  static Archive _decodeZip(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupFormatException(
        '这个文件不是 zip 压缩包（或者已经损坏）。\n'
        '请选择导出时生成的 $kBackupFileNamePrefix*.zip 文件。',
      );
    }
  }

  // ---------------- 给人看的文本 ----------------

  /// `任务 12 · 目标 4 · 日记 30`（只列非空表）。
  static String describeCounts(Map<String, int> counts) {
    final List<String> parts = <String>[
      for (final String table in BackupTables.ordered)
        if ((counts[table] ?? 0) > 0)
          '${BackupTables.labels[table] ?? table} ${counts[table]}',
    ];
    return parts.isEmpty ? '没有任何数据' : parts.join(' · ');
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
