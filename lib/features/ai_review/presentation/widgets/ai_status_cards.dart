import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bounce_tap.dart';
import '../../../../data/services/ai/ai_config.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 配置状态卡：已配置就显示摘要，没配 Key 就提示去设置。
class AiConfigCard extends StatelessWidget {
  const AiConfigCard({
    super.key,
    required this.loading,
    this.config,
    required this.onOpenSettings,
  });

  final bool loading;
  final AiConfig? config;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    if (loading || config == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 14),
            Text('正在读取 AI 配置…', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    final AiConfig cfg = config!;
    final bool ready = cfg.hasKey;
    final Color color = ready ? c.violet : c.amber;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              ready ? Icons.smart_toy_rounded : Icons.key_off_rounded,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  ready ? '${cfg.vendorName} · ${cfg.model}' : '还没有配置 API Key',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ready
                      ? 'Key ${cfg.maskedKey} · 数据只发往你选择的服务商'
                      : '到设置里填一个 Key 就能开始生成复盘',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BounceTap(
            onTap: onOpenSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.settings_rounded, size: 13, color: color),
                  const SizedBox(width: 5),
                  Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 生成中：显示当前步骤、已等待时间 + 进度条 + 取消按钮。
class AiRunningCard extends StatefulWidget {
  const AiRunningCard({super.key, required this.step, required this.onCancel});

  final String step;
  final VoidCallback onCancel;

  @override
  State<AiRunningCard> createState() => _AiRunningCardState();
}

class _AiRunningCardState extends State<AiRunningCard> {
  final Stopwatch _watch = Stopwatch()..start();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每秒跳一下：让「在跑」看得见，不至于像卡死
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final int seconds = _watch.elapsed.inSeconds;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: c.review,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.violet.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'AI 正在读你的一天',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.medium,
                  child: Text(
                    widget.step.isEmpty ? '处理中…' : widget.step,
                    key: ValueKey<String>(widget.step),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$seconds 秒',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (seconds >= 20) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '推理模型会先思考一会儿；等不及可以取消，或把模型换成非推理模型（快得多）。',
              style: TextStyle(
                color: c.card,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          BounceTap(
            onTap: widget.onCancel,
            scale: 0.98,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.stop_circle_outlined, size: 17, color: Colors.white),
                  SizedBox(width: 7),
                  Text(
                    '取消生成',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 错误卡：显示原因 + 重试。
class AiErrorCard extends StatelessWidget {
  const AiErrorCard({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.onDismiss,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.danger.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: c.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              if (onDismiss != null)
                BounceTap(
                  onTap: onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: c.inkFaint,
                    ),
                  ),
                ),
            ],
          ),
          if (detail != null && detail!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            Text(
              detail!,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.55,
                color: c.inkFaint,
              ),
            ),
          ],
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 12),
            BounceTap(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.refresh_rounded, size: 14, color: c.danger),
                    const SizedBox(width: 5),
                    Text(
                      '重试',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
