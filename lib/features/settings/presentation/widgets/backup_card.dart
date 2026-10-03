import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../../../data/services/backup/backup_service.dart';
import '../../providers/backup_providers.dart';

/// 设置页的「数据备份与恢复」卡。
///
/// 用途：换机、或者换正式签名前先卸载重装时，把全部数据存成一个 zip 放到
/// 手机的公共目录（下载），重装后导回来。
class BackupCard extends ConsumerStatefulWidget {
  const BackupCard({super.key});

  @override
  ConsumerState<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<BackupCard> {
  bool _busy = false;
  String? _status;
  bool _failed = false;

  BackupService get _service => ref.read(backupServiceProvider);

  void _setStatus(String? text, {bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _failed = failed;
    });
  }

  void _toast(String text, {bool failed = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failed ? '⚠️ $text' : text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ---------------- 导出 ----------------

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final BackupExportResult result = await _service.export();
      if (result.cancelled) {
        _setStatus('已取消导出');
        return;
      }
      _setStatus(
        '已导出 ${result.totalRows} 条记录'
        '${result.imageCount > 0 ? ' + ${result.imageCount} 张配图' : ''}'
        '（${result.sizeText}）',
      );
      if (result.missingImages > 0) {
        _toast(
          '备份已保存，但有 ${result.missingImages} 张配图的文件在手机上找不到了',
          failed: true,
        );
      } else {
        _toast('备份已保存到你选的位置，卸载 App 也不会删');
      }
    } catch (e) {
      _setStatus('导出失败：${_brief(e)}', failed: true);
      _toast('导出失败', failed: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------- 导入 ----------------

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final PendingBackup? pending = await _service.pickForImport();
      if (pending == null) {
        _setStatus('已取消导入');
        return;
      }

      final bool? ok = await _confirm(pending);
      if (ok != true) {
        _setStatus('已取消导入');
        return;
      }

      final BackupImportResult result = await _service.restore(pending);
      _setStatus(
        '已恢复 ${result.totalRows} 条记录'
        '${result.imageCount > 0 ? ' + ${result.imageCount} 张配图' : ''}',
      );
      if (result.problemImages > 0) {
        _toast(
          '导入完成，但有 ${result.problemImages} 张配图没能恢复（其余数据都在）',
          failed: true,
        );
      } else {
        _toast('导入完成，数据已恢复到备份时的样子');
      }
    } catch (e) {
      _setStatus('导入失败：${_brief(e)}', failed: true);
      _toast('导入失败，原有数据没有被改动', failed: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(PendingBackup pending) {
    final AppScheme c = context.scheme;
    final DateTime? at = pending.exportedAt;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text('用备份覆盖当前数据？', style: TextStyle(fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '文件：${pending.fileName}',
                style: TextStyle(fontSize: 12, height: 1.5, color: c.inkFaint),
              ),
              const SizedBox(height: 4),
              Text(
                '导出时间：${at == null ? '未知' : DayUtils.formatDateTime(at)}',
                style: TextStyle(fontSize: 12, height: 1.5, color: c.inkFaint),
              ),
              const SizedBox(height: 12),
              Text(
                '将恢复：',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                BackupService.describeCounts(pending.counts),
                style: TextStyle(fontSize: 12.5, height: 1.6, color: c.inkSoft),
              ),
              if (pending.imageCount > 0) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  '配图 ${pending.imageCount} 张',
                  style:
                      TextStyle(fontSize: 12.5, height: 1.6, color: c.inkSoft),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.amber.withValues(alpha: 0.30)),
                ),
                child: Text(
                  '会先清空当前 App 里的全部数据（任务 / 目标 / 日记 / 数据 / 日志 / '
                  'AI 复盘 / 设置），再用备份覆盖，无法撤销。\n\n'
                  'AI 的 API Key 不在备份里（它只存在系统安全存储里），'
                  '导入后需要自己重新填一次。',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.7,
                    color: c.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '覆盖导入',
              style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _brief(Object e) {
    final String text = e
        .toString()
        .replaceAll('\n', ' ')
        .replaceAll('BackupFormatException: ', '');
    return text.length <= 70 ? text : '${text.substring(0, 70)}…';
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;

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
                  color: c.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 19,
                  color: c.violet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '备份与恢复',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '导出一个 zip（数据 + 日记配图），重装或换机后导回来',
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
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  label: '导出备份',
                  icon: Icons.file_upload_outlined,
                  color: c.mint,
                  busy: _busy,
                  onTap: _export,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: '导入备份',
                  icon: Icons.file_download_outlined,
                  color: c.amber,
                  busy: _busy,
                  onTap: _import,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '导出时在系统对话框里选「下载」目录：那是公共存储，'
            '卸载 App 不会删。导入会覆盖当前数据，'
            'API Key 需要重新填一次。',
            style: TextStyle(fontSize: 11, height: 1.7, color: c.inkFaint),
          ),
          if (_status != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: (_failed ? c.danger : c.mint).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _status!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: _failed ? c.danger : c.mintDeep,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 卡片里的两个动作按钮（和「数据维护」卡的按钮同一套观感）。
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return BounceTap(
      onTap: busy ? null : onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: busy ? 0.05 : 0.09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: busy ? 0.16 : 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              busy ? Icons.hourglass_top_rounded : icon,
              size: 15,
              color: busy ? c.inkFaint : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: busy ? c.inkFaint : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
