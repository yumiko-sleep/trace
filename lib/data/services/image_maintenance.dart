import 'dart:io';

import '../db/app_database.dart';
import '../repositories/diary_repository.dart';
import 'image_storage.dart';

/// 一次配图扫描 / 清理的结果。
class ImageCleanupReport {
  const ImageCleanupReport({
    required this.scanned,
    required this.referenced,
    required this.orphans,
    required this.removed,
    required this.bytesFreed,
    required this.missing,
    this.errors = const <String>[],
    required this.cleaned,
  });

  /// 目录里扫到的文件数
  final int scanned;

  /// 数据库里被日记引用的文件数
  final int referenced;

  /// 没被任何日记引用的文件数（scan 时是「可清理」的数量）
  final int orphans;

  /// 本次实际删掉的文件数（scan 时恒为 0）
  final int removed;

  /// 释放的字节数（scan 时是「可释放」的字节数）
  final int bytesFreed;

  /// 数据库引用了、但磁盘上找不到的文件数（不正常，值得提醒）
  final int missing;

  final List<String> errors;

  /// 是否是「真删过」的结果
  final bool cleaned;

  bool get hasOrphans => orphans > 0;

  String get humanSize => formatBytes(bytesFreed);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 日记配图的维护。
///
/// 背景：左滑删除日记时**刻意保留**图片文件，这样「撤销」能把图片一起恢复；
/// 代价是删掉的日记会留下孤儿文件。这里提供显式扫描 / 清理：
/// - [scan] 只统计，不动文件（进设置页时调用）
/// - [clean] 真正删除不被任何日记引用的文件
class ImageMaintenance {
  ImageMaintenance(
    this._repo, {
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? ImageStorage.directory;

  final DiaryRepository _repo;
  final Future<Directory> Function() _directoryProvider;

  /// 只统计，不删除。返回的 [ImageCleanupReport.orphans] 就是可清理数量。
  Future<ImageCleanupReport> scan() => _run(delete: false);

  /// 真删除孤儿文件。
  Future<ImageCleanupReport> clean() => _run(delete: true);

  Future<ImageCleanupReport> _run({required bool delete}) async {
    final Set<String> referenced = await _referencedPaths();

    Directory dir;
    try {
      dir = await _directoryProvider();
    } on Exception catch (e) {
      return ImageCleanupReport(
        scanned: 0,
        referenced: referenced.length,
        orphans: 0,
        removed: 0,
        bytesFreed: 0,
        missing: 0,
        errors: <String>['读取配图目录失败：$e'],
        cleaned: delete,
      );
    }

    int scanned = 0;
    int orphans = 0;
    int removed = 0;
    int bytes = 0;
    final List<String> errors = <String>[];

    if (dir.existsSync()) {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final FileSystemEntity entity in entities) {
        if (entity is! File) continue;
        scanned++;
        if (referenced.contains(entity.path)) continue;
        orphans++;
        try {
          final int size = await entity.length();
          bytes += size;
          if (delete) {
            await entity.delete();
            removed++;
          }
        } on FileSystemException catch (e) {
          errors.add('${entity.uri.pathSegments.last}：${e.message}');
        }
      }
    }

    // 数据库引用了但磁盘上没有：不正常（例如用户手动清理过），值得提醒
    int missing = 0;
    for (final String path in referenced) {
      if (!File(path).existsSync()) missing++;
    }

    return ImageCleanupReport(
      scanned: scanned,
      referenced: referenced.length,
      orphans: orphans,
      removed: removed,
      bytesFreed: bytes,
      missing: missing,
      errors: errors,
      cleaned: delete,
    );
  }

  Future<Set<String>> _referencedPaths() async {
    final List<DiaryEntry> entries = await _repo.getAll();
    if (entries.isEmpty) return <String>{};
    final Map<int, List<DiaryImage>> images = await _repo.getImagesForEntries(
      entries.map((DiaryEntry e) => e.id).toList(growable: false),
    );
    return <String>{
      for (final List<DiaryImage> list in images.values)
        for (final DiaryImage image in list) image.path,
    };
  }
}
