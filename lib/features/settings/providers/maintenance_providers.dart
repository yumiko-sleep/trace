import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/data_providers.dart';
import '../../../data/services/image_maintenance.dart';

/// 配图维护（孤儿文件扫描 / 清理）。
final Provider<ImageMaintenance> imageMaintenanceProvider =
    Provider<ImageMaintenance>(
  (Ref ref) => ImageMaintenance(ref.watch(diaryRepositoryProvider)),
);

/// 进设置页时自动跑一次扫描（只读，不动文件）。
final AutoDisposeFutureProvider<ImageCleanupReport> imageCleanupScanProvider =
    FutureProvider.autoDispose<ImageCleanupReport>(
  (Ref ref) => ref.watch(imageMaintenanceProvider).scan(),
);

final Provider<ImageMaintenanceActions> imageMaintenanceActionsProvider =
    Provider<ImageMaintenanceActions>((Ref ref) => ImageMaintenanceActions(ref));

class ImageMaintenanceActions {
  ImageMaintenanceActions(this._ref);

  final Ref _ref;

  /// 真删除孤儿图片，然后让扫描结果重新拉一次。
  Future<ImageCleanupReport> clean() async {
    final ImageCleanupReport report =
        await _ref.read(imageMaintenanceProvider).clean();
    _ref.invalidate(imageCleanupScanProvider);
    return report;
  }

  Future<void> rescan() async {
    _ref.invalidate(imageCleanupScanProvider);
    await _ref.read(imageCleanupScanProvider.future);
  }
}
