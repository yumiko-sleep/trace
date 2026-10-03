import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trace/data/dao/diary_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/repositories/diary_repository.dart';
import 'package:trace/data/services/image_maintenance.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiaryRepository diary;
  late Directory tempDir;
  late ImageMaintenance maintenance;

  setUp(() async {
    db = openTestDatabase();
    diary = DiaryRepository(DiaryDao(db));
    tempDir = await Directory.systemTemp.createTemp('trace_images_');
    maintenance = ImageMaintenance(
      diary,
      directoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> fake(String name, {int bytes = 100}) async {
    final File file = File(p.join(tempDir.path, name));
    await file.writeAsBytes(List<int>.filled(bytes, 0));
    return file;
  }

  test('scan 只统计，clean 真删；被引用的图片必须保住', () async {
    final File kept = await fake('kept.jpg', bytes: 2048);
    final File kept2 = await fake('kept2.jpg', bytes: 512);
    final File orphan = await fake('orphan.jpg', bytes: 4096);
    await Directory(p.join(tempDir.path, 'sub')).create();

    await diary.saveEntry(
      date: DateTime.now(),
      content: '今天配了两张图',
      imagePaths: <String>[kept.path, kept2.path],
    );

    final ImageCleanupReport scan = await maintenance.scan();
    expect(scan.scanned, 3, reason: '子目录不算文件');
    expect(scan.referenced, 2);
    expect(scan.orphans, 1);
    expect(scan.cleaned, isFalse);
    expect(scan.removed, 0, reason: 'scan 不动文件');
    expect(scan.bytesFreed, 4096, reason: '这里表示「可释放」');
    expect(orphan.existsSync(), isTrue);
    expect(scan.humanSize, '4.0 KB');

    final ImageCleanupReport cleaned = await maintenance.clean();
    expect(cleaned.cleaned, isTrue);
    expect(cleaned.orphans, 1, reason: '清理前查到的孤儿数');
    expect(cleaned.removed, 1);
    expect(cleaned.bytesFreed, 4096);
    expect(orphan.existsSync(), isFalse);
    expect(kept.existsSync(), isTrue);
    expect(kept2.existsSync(), isTrue);
    expect(cleaned.errors, isEmpty);
  });

  test('没有孤儿时什么都不删', () async {
    final File kept = await fake('kept.jpg');
    await diary.saveEntry(
      date: DateTime.now(),
      content: '一张图',
      imagePaths: <String>[kept.path],
    );

    final ImageCleanupReport cleaned = await maintenance.clean();
    expect(cleaned.orphans, 0);
    expect(cleaned.removed, 0);
    expect(kept.existsSync(), isTrue);
  });

  test('数据库引用了但磁盘上没有 → missing 计数', () async {
    await diary.saveEntry(
      date: DateTime.now(),
      content: '图片被手动删掉了',
      imagePaths: <String>[p.join(tempDir.path, 'missing.jpg')],
    );

    final ImageCleanupReport scan = await maintenance.scan();
    expect(scan.scanned, 0);
    expect(scan.referenced, 1);
    expect(scan.missing, 1);
  });

  test('没有日记时目录里的文件都算孤儿', () async {
    await fake('a.jpg', bytes: 10);
    await fake('b.jpg', bytes: 20);

    final ImageCleanupReport scan = await maintenance.scan();
    expect(scan.referenced, 0);
    expect(scan.orphans, 2);
    expect(scan.bytesFreed, 30);
  });

  test('目录不存在时不报错', () async {
    final ImageMaintenance m = ImageMaintenance(
      diary,
      directoryProvider: () async => Directory(p.join(tempDir.path, 'nope')),
    );

    final ImageCleanupReport scan = await m.scan();
    expect(scan.scanned, 0);
    expect(scan.orphans, 0);
    expect(scan.errors, isEmpty);
  });

  test('formatBytes 可读化', () {
    expect(ImageCleanupReport.formatBytes(0), '0 B');
    expect(ImageCleanupReport.formatBytes(512), '512 B');
    expect(ImageCleanupReport.formatBytes(2048), '2.0 KB');
    expect(ImageCleanupReport.formatBytes(3 * 1024 * 1024), '3.0 MB');
  });
}
