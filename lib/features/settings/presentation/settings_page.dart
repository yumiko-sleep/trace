import 'package:flutter/material.dart';

import '../../../core/widgets/info_note.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/section_scaffold.dart';
import '../../../core/widgets/soft_card.dart';
import 'widgets/ai_settings_card.dart';
import 'widgets/backup_card.dart';
import 'widgets/data_maintenance_card.dart';
import 'widgets/theme_settings_card.dart';
import '../../../core/theme/app_scheme.dart';
import '../../../core/theme/app_theme.dart';

/// 设置页。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return SectionScaffold(
      showBack: false,
      title: '设置',
      subtitle: 'AI 供应商、密钥与数据说明',
      icon: Icons.tune_rounded,
      gradient: c.header,
      children: <Widget>[
        const _IdentityCard(),
        const SizedBox(height: 20),
        const SectionHeader(
          title: '外观主题',
          subtitle: '两套配色 × 浅色 / 深色，改完立刻生效',
        ),
        const SizedBox(height: 12),
        const ThemeSettingsCard(),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'AI 复盘',
          subtitle: '填一次就能用；Key 只存在这台手机上',
        ),
        const SizedBox(height: 12),
        const AiSettingsCard(),
        const SizedBox(height: 20),
        const SectionHeader(
          title: '数据维护',
          subtitle: '清理日记残留的图片文件',
        ),
        const SizedBox(height: 12),
        const DataMaintenanceCard(),
        const SizedBox(height: 20),
        const SectionHeader(
          title: '数据备份',
          subtitle: '导出成一个 zip（含日记配图），卸载重装后导回来',
        ),
        const SizedBox(height: 12),
        const BackupCard(),
        const SizedBox(height: 20),
        const SectionHeader(title: '其他', subtitle: '数据与协议说明'),
        const SizedBox(height: 12),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: <Widget>[
              const _SettingRow(
                icon: Icons.storage_rounded,
                label: '数据存储',
                value: '本地 SQLite，不上传',
              ),
              Divider(height: 1, color: c.line),
              const _SettingRow(
                icon: Icons.balance_rounded,
                label: '开源协议',
                value: 'MIT',
              ),
              Divider(height: 1, color: c.line),
              const _SettingRow(
                icon: Icons.info_outline_rounded,
                label: '版本',
                value: 'v0.1.0',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const InfoNote(
          text: '关于隐私：任务、目标、日记、数据、日志全部只存在你手机的本地数据库里。'
              '只有当你在「AI 复盘」页手动点「生成今天的复盘」时，'
              '才会把当天的数据打包成 JSON 发给你选择的服务商；'
              'API Key 保存在系统安全存储（Android Keystore / iOS Keychain）中，'
              '既不写进代码，也不存进数据库。',
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final TextTheme t = Theme.of(context).textTheme;

    return SoftCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: c.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.cyan.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('轨迹 Trace', style: t.titleLarge),
                const SizedBox(height: 4),
                Text('完全开源 · 免费 · 数据只存本机', style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.mint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: c.mintDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12.5, color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}
