import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/app.dart';
import 'package:trace/data/db/app_database.dart';
import 'package:trace/data/providers/data_providers.dart';
import 'package:trace/data/services/backup/backup_service.dart';
import 'package:trace/data/services/backup/trace_backup.dart';
import 'package:trace/features/settings/providers/backup_providers.dart';

import '../../helpers/test_database.dart';

/// 只记录调用、不碰文件系统的替身。
class _FakeBackupService implements BackupService {
  int exportCalls = 0;
  int restoreCalls = 0;
  bool cancelExport = false;
  PendingBackup? pendingToReturn;

  @override
  Future<BackupExportResult> export() async {
    exportCalls++;
    return BackupExportResult(
      savedTo: cancelExport
          ? null
          : Uri.parse('content://downloads/trace_backup_20261003_1624.zip'),
      counts: <String, int>{BackupTables.tasks: 3, BackupTables.goals: 1},
      imageCount: 2,
      missingImages: 0,
      bytes: 2048,
    );
  }

  @override
  Future<PendingBackup?> pickForImport() async => pendingToReturn;

  @override
  PendingBackup parse(PickedBackupFile picked) => throw UnimplementedError();

  @override
  Future<BackupImportResult> restore(PendingBackup pending) async {
    restoreCalls++;
    return const BackupImportResult(
      counts: <String, int>{BackupTables.tasks: 3, BackupTables.goals: 1},
      imageCount: 2,
      missingImages: 0,
    );
  }
}

PendingBackup _pending() => PendingBackup(
      fileName: 'trace_backup_20261003_1624.zip',
      backup: TraceBackup(
        rows: <String, List<Map<String, dynamic>>>{
          BackupTables.tasks: <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
            <String, dynamic>{'id': 2},
            <String, dynamic>{'id': 3},
          ],
          BackupTables.goals: <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
          ],
          BackupTables.diaryImages: <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'path': 'a.jpg'},
            <String, dynamic>{'id': 2, 'path': 'b.jpg'},
          ],
        },
        exportedAt: DateTime(2026, 10, 3, 16, 24),
        appVersion: '0.1.0+1',
      ),
      archive: Archive(),
    );

/// 进设置页（底部导航的「设置」）。
Future<void> _openSettings(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.byIcon(Icons.tune_rounded));
  await _settle(tester);
}

/// 不用 pumpAndSettle：底部导航和卡片的动画是无限的。
Future<void> _settle(WidgetTester tester, {int times = 14}) async {
  for (int i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// 让浮动的 SnackBar 自己消失，免得挡住下面的按钮。
Future<void> _dismissSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await _settle(tester, times: 4);
}

void main() {
  late AppDatabase db;
  late _FakeBackupService fake;

  setUp(() {
    db = openTestDatabase();
    fake = _FakeBackupService();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          backupServiceProvider.overrideWithValue(fake),
        ],
        child: const TraceApp(),
      ),
    );
    await _openSettings(tester);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(label));
    await _settle(tester);
  }

  testWidgets('导出：按钮可用并给出结果提示', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.text('导出备份'), findsOneWidget);
    expect(find.text('导入备份'), findsOneWidget);
    expect(
      find.textContaining('卸载 App 不会删'),
      findsOneWidget,
      reason: '要写清楚导出的文件放哪才安全',
    );

    await tapButton(tester, '导出备份');

    expect(fake.exportCalls, 1);
    expect(find.textContaining('已导出 4 条记录 + 2 张配图'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('导出取消：只说取消了，不是失败', (WidgetTester tester) async {
    fake.cancelExport = true;
    await pumpApp(tester);

    await tapButton(tester, '导出备份');

    expect(fake.exportCalls, 1);
    expect(find.text('已取消导出'), findsOneWidget);
    expect(find.textContaining('导出失败'), findsNothing);

    await _dismissSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('导入：先弹确认（写明会清空 + Key 要重填），确认后才恢复',
      (WidgetTester tester) async {
    fake.pendingToReturn = _pending();
    await pumpApp(tester);

    await tapButton(tester, '导入备份');

    // 确认弹窗
    expect(find.text('用备份覆盖当前数据？'), findsOneWidget);
    expect(find.textContaining('trace_backup_20261003_1624.zip'), findsOneWidget);
    expect(find.textContaining('2026-10-03 16:24'), findsOneWidget);
    expect(find.textContaining('任务 3 · 配图 2'), findsOneWidget);
    expect(find.textContaining('AI 的 API Key 不在备份里'), findsOneWidget);
    expect(find.textContaining('无法撤销'), findsOneWidget);
    expect(fake.restoreCalls, 0, reason: '还没点确认，不能动数据');

    await tester.tap(find.text('覆盖导入'));
    await _settle(tester);

    expect(fake.restoreCalls, 1);
    expect(find.textContaining('已恢复 4 条记录 + 2 张配图'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('导入：在确认弹窗点「再想想」什么都不做', (WidgetTester tester) async {
    fake.pendingToReturn = _pending();
    await pumpApp(tester);

    await tapButton(tester, '导入备份');
    expect(find.text('用备份覆盖当前数据？'), findsOneWidget);

    await tester.tap(find.text('再想想'));
    await _settle(tester);

    expect(fake.restoreCalls, 0);
    expect(find.text('已取消导入'), findsOneWidget);

    await _dismissSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('导入：用户在系统选择器里取消 → 返回后只说取消', (WidgetTester tester) async {
    fake.pendingToReturn = null;
    await pumpApp(tester);

    await tapButton(tester, '导入备份');

    expect(fake.restoreCalls, 0);
    expect(find.text('已取消导入'), findsOneWidget);
    expect(find.text('用备份覆盖当前数据？'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
