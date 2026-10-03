import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/data_providers.dart';
import '../../../data/services/backup/backup_service.dart';

/// 数据备份 / 恢复服务。
///
/// 测试里可以覆盖成内存替身，避免真的弹系统文件对话框。
final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (Ref ref) => BackupService(ref.watch(appDatabaseProvider)),
);
