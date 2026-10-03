import 'package:trace/data/db/app_database.dart';

import 'sqlite_loader.dart';

/// 打开一个纯内存数据库，供单元测试使用。
///
/// 每个测试用例都应该自己开一个，互不干扰。
AppDatabase openTestDatabase() {
  ensureSqliteAvailable();
  return AppDatabase.memory();
}
