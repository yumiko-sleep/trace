import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 打开落盘数据库：文件放在 App 私有目录下的 `trace.sqlite`。
///
/// `createInBackground` 会把数据库操作放到独立 isolate，
/// 避免大量查询/写入卡住 UI 线程。
LazyDatabase openAppConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'trace.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// 仅用于调试/测试的临时文件数据库。
LazyDatabase openTemporaryConnection(String fileName) {
  return LazyDatabase(() async {
    final Directory dir = await Directory.systemTemp.createTemp('trace_db_');
    final File file = File(p.join(dir.path, fileName));
    return NativeDatabase.createInBackground(file);
  });
}
