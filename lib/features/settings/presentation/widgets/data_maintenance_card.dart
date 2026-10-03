import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../../../data/services/image_maintenance.dart';
import '../../providers/maintenance_providers.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 设置页的「数据维护」卡：扫描并清理日记的孤儿配图。
///
/// 为什么会有孤儿：左滑删除日记时故意保留图片文件，让「撤销」能连图恢复；
/// 删掉又不撤销的那些日记，其图片就成了没人引用的孤儿。
class DataMaintenanceCard extends ConsumerStatefulWidget {
  const DataMaintenanceCard({super.key});

  @override
  ConsumerState<DataMaintenanceCard> createState() =>
      _DataMaintenanceCardState();
}

class _DataMaintenanceCardState extends ConsumerState<DataMaintenanceCard> {
  bool _busy = false;

  Future<void> _confirmAndClean(ImageCleanupReport scan) async {
    final AppScheme c = context.scheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text('清理孤儿图片？', style: TextStyle(fontSize: 17)),
        content: Text(
          '会删除 ${scan.orphans} 个没有被任何日记引用的图片文件'
          '（约 ${scan.humanSize}）。\n\n'
          '已删除的日记如果还在「撤销」期限内，撤销后图片会显示不出来。',
          style: const TextStyle(fontSize: 13.5, height: 1.6),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('先不清'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '清理',
              style: TextStyle(
                color: c.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ImageCleanupReport result =
          await ref.read(imageMaintenanceActionsProvider).clean();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.errors.isEmpty
                  ? '已清理 ${result.removed} 个文件，释放 ${result.humanSize}'
                  : '清理完成，但有 ${result.errors.length} 个文件没删掉',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final AsyncValue<ImageCleanupReport> scan =
        ref.watch(imageCleanupScanProvider);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.sky.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  size: 19,
                  color: c.sky,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '配图文件维护',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '删日记时会保留图片以便撤销，这里清理没人引用的残留',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          scan.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '正在扫描配图目录…',
                    style: TextStyle(fontSize: 12.5, color: c.inkFaint),
                  ),
                ],
              ),
            ),
            error: (Object e, StackTrace _) => Text(
              '扫描失败：$e',
              style: TextStyle(fontSize: 12.5, color: c.danger),
            ),
            data: (ImageCleanupReport report) => _ReportBody(
              report: report,
              busy: _busy,
              onRescan: () async {
                setState(() => _busy = true);
                try {
                  await ref.read(imageMaintenanceActionsProvider).rescan();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
              onClean: report.hasOrphans
                  ? () => _confirmAndClean(report)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.report,
    required this.busy,
    required this.onRescan,
    this.onClean,
  });

  final ImageCleanupReport report;
  final bool busy;
  final VoidCallback onRescan;
  final VoidCallback? onClean;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Stat(label: '配图文件', value: '${report.scanned} 个'),
            _Stat(
              label: '可清理',
              value: report.hasOrphans
                  ? '${report.orphans} 个 · ${report.humanSize}'
                  : '无',
              highlight: report.hasOrphans,
            ),
            _Stat(label: '被引用', value: '${report.referenced} 个'),
          ],
        ),
        if (report.missing > 0) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            '有 ${report.missing} 条日记引用的图片文件在磁盘上找不到了'
            '（可能是被手动清理过）。日记内容不受影响。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: c.amber,
            ),
          ),
        ],
        if (report.errors.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            '有 ${report.errors.length} 个文件处理失败：${report.errors.first}',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: c.danger,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: BounceTap(
                onTap: busy ? null : onRescan,
                scale: 0.98,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.sky.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: c.sky.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        busy ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                        size: 15,
                        color: c.sky,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        busy ? '处理中…' : '重新扫描',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.sky,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BounceTap(
                onTap: busy ? null : onClean,
                scale: 0.98,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: 46,
                  decoration: BoxDecoration(
                    color: onClean == null
                        ? c.bgBottom.withValues(alpha: 0.7)
                        : c.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: onClean == null
                          ? c.line
                          : c.danger.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.delete_sweep_rounded,
                        size: 16,
                        color: onClean == null
                            ? c.inkFaint
                            : c.danger,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '清理孤儿图片',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: onClean == null
                              ? c.inkFaint
                              : c.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: highlight ? c.amber : c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}
