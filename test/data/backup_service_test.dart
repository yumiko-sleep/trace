import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trace/data/dao/diary_dao.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/repositories/diary_repository.dart';
import 'package:trace/data/services/backup/backup_service.dart';
import 'package:trace/data/services/backup/trace_backup.dart';

import '../helpers/test_database.dart';

/// 内存版「系统文件选择器」：导出不弹对话框，导入直接吐预先准备好的字节。
class _FakeGateway implements BackupFileGateway {
  bool cancelSave = false;
  PickedBackupFile? toPick;

  String? savedName;
  String? savedMimeType;
  Uint8List? savedBytes;

  @override
  Future<Uri?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (cancelSave) return null;
    savedName = fileName;
    savedBytes = bytes;
    savedMimeType = mimeType;
    return Uri.parse('content://downloads/$fileName');
  }

  @override
  Future<PickedBackupFile?> pickBackupFile() async => toPick;
}

/// 配图在 App 私有目录里的文件名（ImageStorage 生成的那个样子）。
const String _imageName = '1700000000000_0_0.jpg';

void main() {
  late AppDatabase db;
  late Directory images;
  late _FakeGateway gateway;
  late BackupService service;

  setUp(() async {
    db = openTestDatabase();
    images = await Directory.systemTemp.createTemp('trace_backup_images_');
    gateway = _FakeGateway();
    service = BackupService(
      db,
      gateway: gateway,
      imagesDirectory: () async => images,
    );
  });

  tearDown(() async {
    await db.close();
    if (images.existsSync()) await images.delete(recursive: true);
  });

  /// 造一条带配图的日记，图片文件真的写到目录里。
  Future<File> seedDiaryWithImage({int bytes = 2048}) async {
    final File file = File(p.join(images.path, _imageName));
    await file.writeAsBytes(List<int>.filled(bytes, 7));
    await DiaryRepository(DiaryDao(db)).saveEntry(
      date: DateTime(2026, 10, 3),
      content: '今天跑了 5 公里',
      imagePaths: <String>[file.path],
    );
    return file;
  }

  test('导出：包里有 data.json 和 images/，文件名带时间', () async {
    await seedDiaryWithImage();

    final BackupExportResult result = await service.export();

    expect(result.cancelled, isFalse);
    expect(result.imageCount, 1);
    expect(result.missingImages, 0);
    expect(result.counts[BackupTables.diaryEntries], 1);
    expect(result.bytes, greaterThan(0));
    expect(result.sizeText, endsWith('KB'));
    expect(
      gateway.savedName,
      matches(RegExp(r'^trace_backup_\d{8}_\d{4}\.zip$')),
    );
    expect(gateway.savedMimeType, 'application/zip');

    final Archive archive = ZipDecoder().decodeBytes(gateway.savedBytes!);
    final ArchiveFile? data = archive.find(kBackupDataEntry);
    expect(data, isNotNull);
    final ArchiveFile? image =
        archive.find('$kBackupImagesDir/$_imageName');
    expect(image, isNotNull);
    expect(image!.content.length, 2048);

    final TraceBackup parsed = TraceBackup.decode(data!.content);
    expect(parsed.rows[BackupTables.diaryEntries], hasLength(1));
    expect(
      parsed.appVersion,
      BackupService.appVersion,
      reason: '备份里要记下导出时的版本号，方便以后回溯',
    );
    expect(
      parsed.rows[BackupTables.diaryImages]!.single['path'],
      _imageName,
      reason: '备份里只留文件名',
    );
    expect(parsed.totalRows, greaterThan(0));
  });

  test('导出时用户在系统对话框取消 → 明确返回 cancelled', () async {
    await seedDiaryWithImage();
    gateway.cancelSave = true;

    final BackupExportResult result = await service.export();

    expect(result.cancelled, isTrue);
    expect(gateway.savedBytes, isNull);
    expect(result.imageCount, 1, reason: '只是没保存，统计信息照样给出');
  });

  test('导入：换一台设备（新目录 + 空数据库）也能完整还原', () async {
    final File original = await seedDiaryWithImage();
    await service.export();
    final PickedBackupFile picked = PickedBackupFile(
      name: gateway.savedName!,
      bytes: gateway.savedBytes!,
    );

    // 模拟重装：新数据库 + 全新的配图目录
    final AppDatabase fresh = openTestDatabase();
    addTearDown(fresh.close);
    final Directory freshImages =
        await Directory.systemTemp.createTemp('trace_restored_images_');
    addTearDown(() async {
      if (freshImages.existsSync()) await freshImages.delete(recursive: true);
    });

    final _FakeGateway restoreGateway = _FakeGateway()..toPick = picked;
    final BackupService restoring = BackupService(
      fresh,
      gateway: restoreGateway,
      imagesDirectory: () async => freshImages,
    );

    final PendingBackup? pending = await restoring.pickForImport();
    expect(pending, isNotNull);
    expect(pending!.fileName, gateway.savedName);
    expect(pending.exportedAt, isNotNull);
    expect(pending.counts[BackupTables.diaryImages], 1);

    final BackupImportResult result = await restoring.restore(pending);

    expect(result.imageCount, 1);
    expect(result.missingImages, 0);
    expect(result.problemImages, 0);
    expect(result.counts[BackupTables.diaryEntries], 1);

    // 图片落在新目录里，内容一致
    final File restoredImage = File(p.join(freshImages.path, _imageName));
    expect(restoredImage.existsSync(), isTrue);
    expect(await restoredImage.length(), await original.length());

    // 数据库里的路径指向新目录，不再指向导出时的老路径
    final DiaryImage image =
        (await fresh.select(fresh.diaryImages).get()).single;
    expect(image.path, p.join(freshImages.path, _imageName));
    expect(image.path, isNot(original.path));

    final DiaryEntry entry = (await fresh.select(fresh.diaryEntries).get()).single;
    expect(entry.content, '今天跑了 5 公里');
    expect(entry.date, DateTime(2026, 10, 3));
  });

  test('导入会覆盖已有数据（不是合并）', () async {
    await seedDiaryWithImage();
    await service.export();
    final PickedBackupFile picked = PickedBackupFile(
      name: gateway.savedName!,
      bytes: gateway.savedBytes!,
    );

    // 目标库里先有一条「不该活下来」的日记
    await DiaryRepository(DiaryDao(db)).saveEntry(
      date: DateTime(2026, 9, 1),
      content: '重装后随手写的一条',
    );
    expect((await db.select(db.diaryEntries).get()).length, 2);

    final _FakeGateway restoreGateway = _FakeGateway()..toPick = picked;
    final BackupService restoring = BackupService(
      db,
      gateway: restoreGateway,
      imagesDirectory: () async => images,
    );
    await restoring.restore((await restoring.pickForImport())!);

    final List<DiaryEntry> entries = await db.select(db.diaryEntries).get();
    expect(entries.length, 1);
    expect(entries.single.content, '今天跑了 5 公里');
  });

  test('用户没选文件 → 返回 null（不算错误）', () async {
    gateway.toPick = null;
    expect(await service.pickForImport(), isNull);
  });

  test('选了不是 zip 的文件 → 明确报错', () async {
    gateway.toPick = PickedBackupFile(
      name: '随手选的文件.zip',
      bytes: Uint8List.fromList(utf8.encode('我不是压缩包')),
    );

    await expectLater(
      service.pickForImport(),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('压缩包里没有 data.json → 明确报错', () async {
    final Archive archive = Archive()
      ..add(ArchiveFile.string('读我.txt', '这个包里没有备份数据'));
    gateway.toPick = PickedBackupFile(
      name: 'trace_backup_20261003_1624.zip',
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
    );

    await expectLater(
      service.pickForImport(),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('schema 不是本 App 的 → 明确报错', () async {
    final Archive archive = Archive()
      ..add(
        ArchiveFile.string(
          kBackupDataEntry,
          jsonEncode(<String, dynamic>{'schema': '别人家的备份'}),
        ),
      );
    gateway.toPick = PickedBackupFile(
      name: 'x.zip',
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
    );

    await expectLater(
      service.pickForImport(),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('数据库引用了但磁盘上没有的配图：只计数，导出照样成功', () async {
    await DiaryRepository(DiaryDao(db)).saveEntry(
      date: DateTime(2026, 10, 3),
      content: '图被手动删了',
      imagePaths: <String>[p.join(images.path, 'ghost.jpg')],
    );

    final BackupExportResult result = await service.export();

    expect(result.cancelled, isFalse);
    expect(result.imageCount, 0);
    expect(result.missingImages, 1);
  });

  test('备份里有、包里没有的配图：导入时计入 missingImages', () async {
    // 手动造一个「日记引用了图，但 zip 里没有图」的备份
    final Archive archive = Archive()
      ..add(
        ArchiveFile.string(
          kBackupDataEntry,
          jsonEncode(<String, dynamic>{
            'schema': kTraceBackupSchema,
            'exportedAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
            'data': <String, dynamic>{
              BackupTables.diaryImages: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'entryId': 1,
                  'path': 'lost.jpg',
                  'caption': '',
                  'sortOrder': 0,
                  'createdAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
                },
              ],
            },
          }),
        ),
      );
    gateway.toPick = PickedBackupFile(
      name: 'x.zip',
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
    );

    final BackupImportResult result =
        await service.restore((await service.pickForImport())!);

    expect(result.imageCount, 0);
    expect(result.missingImages, 1);
    expect(result.problemImages, 1);
  });

  test('文本工具：文件名 / 体积 / 中文清单', () {
    expect(
      BackupService.backupFileName(DateTime(2026, 10, 3, 16, 24)),
      'trace_backup_20261003_1624.zip',
    );
    expect(
      BackupService.backupFileName(DateTime(2026, 1, 9, 8, 5)),
      'trace_backup_20260109_0805.zip',
    );
    expect(BackupService.formatSize(0), '0 B');
    expect(BackupService.formatSize(512), '512 B');
    expect(BackupService.formatSize(2048), '2.0 KB');
    expect(BackupService.formatSize(3 * 1024 * 1024), '3.0 MB');

    expect(
      BackupService.describeCounts(<String, int>{
        BackupTables.diaryEntries: 30,
        BackupTables.tasks: 2,
        BackupTables.aiReviews: 0,
      }),
      '任务 2 · 日记 30',
    );
    expect(BackupService.describeCounts(<String, int>{}), '没有任何数据');
  });
}
