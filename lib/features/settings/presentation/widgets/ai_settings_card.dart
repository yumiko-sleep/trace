import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/bounce_tap.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/sheet_form.dart';
import '../../../../core/widgets/soft_card.dart';
import '../../../../data/services/ai/ai_config.dart';
import '../../../../data/services/ai/ai_provider.dart';
import '../../../ai_review/providers/ai_review_providers.dart';
import '../../../../core/theme/app_scheme.dart';
import '../../../../core/theme/app_theme.dart';

/// 设置页里的「AI 复盘」配置卡：服务商 / API Key / 模型名 / 接口地址。
class AiSettingsCard extends ConsumerStatefulWidget {
  const AiSettingsCard({super.key});

  @override
  ConsumerState<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends ConsumerState<AiSettingsCard> {
  final TextEditingController _keyCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();
  final TextEditingController _baseUrlCtrl = TextEditingController();

  String _vendorId = kAiVendors.first.id;
  bool _hasStoredKey = false;
  String _maskedKey = '未配置';
  bool _obscureKey = true;

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _message;
  bool _messageIsError = false;

  AiVendorPreset get _preset => aiVendorById(_vendorId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AiConfig config = await ref.read(aiConfigProvider.future);
    if (!mounted) return;
    setState(() {
      _vendorId = config.vendorId;
      _modelCtrl.text = config.model;
      _baseUrlCtrl.text = config.baseUrl;
      _hasStoredKey = config.hasKey;
      _maskedKey = config.maskedKey;
      _loading = false;
    });
  }

  void _selectVendor(AiVendorPreset preset) {
    final AiVendorPreset previous = _preset;
    setState(() {
      _vendorId = preset.id;
      _message = null;
      // 只在这种情况下帮用户改写：字段是空的，或还留着上一个预设的值
      final String model = _modelCtrl.text.trim();
      if (model.isEmpty || model == previous.defaultModel) {
        _modelCtrl.text = preset.defaultModel;
      }
      final String baseUrl = _baseUrlCtrl.text.trim();
      if (baseUrl.isEmpty || baseUrl == previous.baseUrl) {
        _baseUrlCtrl.text = preset.baseUrl;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    await ref.read(aiConfigActionsProvider).save(
          vendorId: _vendorId,
          baseUrl: _baseUrlCtrl.text,
          model: _modelCtrl.text,
          apiKey: _keyCtrl.text,
        );
    if (!mounted) return;
    _keyCtrl.clear();
    await _load();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = '已保存';
      _messageIsError = false;
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    // 测试前先保存，避免「测的是旧配置」
    await ref.read(aiConfigActionsProvider).save(
          vendorId: _vendorId,
          baseUrl: _baseUrlCtrl.text,
          model: _modelCtrl.text,
          apiKey: _keyCtrl.text,
        );
    _keyCtrl.clear();
    await _load();

    try {
      final String reply = await ref.read(aiConfigActionsProvider).testConnection();
      if (!mounted) return;
      setState(() {
        _testing = false;
        _messageIsError = false;
        _message = '连接成功，模型回复：${reply.isEmpty ? '(空)' : reply}';
      });
    } on AiProviderException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _messageIsError = true;
        _message = e.detail == null ? e.message : '${e.message}\n${e.detail}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _messageIsError = true;
        _message = '测试失败：$e';
      });
    }
  }

  Future<void> _clearKey() async {
    await ref.read(aiConfigActionsProvider).clearKey(_vendorId);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() {
      _message = '已清除这个服务商的 API Key';
      _messageIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final bool busy = _loading || _saving || _testing;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: c.review,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'AI 复盘',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Key 存在系统安全存储里，不会写进代码或数据库',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const SheetLabel('服务商'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final AiVendorPreset preset in kAiVendors)
                SheetChoice(
                  label: preset.name,
                  color: c.violet,
                  selected: _vendorId == preset.id,
                  dense: true,
                  onTap: busy ? () {} : () => _selectVendor(preset),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _preset.note,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: c.inkFaint,
            ),
          ),

          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const SheetLabel('API Key'),
              const SizedBox(width: 8),
              _KeyStateTag(
                hasKey: _hasStoredKey,
                masked: _maskedKey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: c.fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _keyCtrl,
                    obscureText: _obscureKey,
                    cursorColor: c.mint,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.ink,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: _hasStoredKey
                          ? '已保存（$_maskedKey），填这里可覆盖'
                          : '粘贴你的 API Key',
                      hintStyle: TextStyle(
                        color: c.isDark ? c.inkSoft : c.inkFaint,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                BounceTap(
                  onTap: () => setState(() => _obscureKey = !_obscureKey),
                  haptic: false,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _obscureKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 17,
                      color: c.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_hasStoredKey) ...<Widget>[
            const SizedBox(height: 6),
            BounceTap(
              onTap: busy ? null : _clearKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '清除这个服务商的 Key',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.danger,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          const SheetLabel('模型名'),
          const SizedBox(height: 8),
          SheetField(
            controller: _modelCtrl,
            hint: 'deepseek-v4-pro',
          ),
          if (_preset.suggestedModels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String m in _preset.suggestedModels)
                  SheetChoice(
                    label: m,
                    color: c.sky,
                    dense: true,
                    selected: _modelCtrl.text.trim() == m,
                    onTap: busy
                        ? () {}
                        : () => setState(() {
                              _modelCtrl.text = m;
                              _message = null;
                            }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '想快就填非推理模型（如 deepseek-chat）；推理模型（deepseek-v4-pro、名字带 '
            'reasoner / thinking 之类）会先思考几十秒。切换后点「测试连接」验一下。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: c.inkFaint,
            ),
          ),

          const SizedBox(height: 16),
          const SheetLabel('接口地址（baseUrl）'),
          const SizedBox(height: 8),
          SheetField(
            controller: _baseUrlCtrl,
            hint: 'https://api.deepseek.com/v1',
          ),
          const SizedBox(height: 6),
          Text(
            '会请求 baseUrl + /chat/completions；地址要写全（含 /v1 之类的版本段）。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: c.inkFaint,
            ),
          ),

          if (_message != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_messageIsError ? c.danger : c.mintDeep)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_messageIsError ? c.danger : c.mintDeep)
                      .withValues(alpha: 0.24),
                ),
              ),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color:
                      _messageIsError ? c.danger : c.mintDeep,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: GradientButton(
                  label: _saving ? '保存中…' : '保存',
                  icon: Icons.check_rounded,
                  height: 48,
                  gradient: c.review,
                  onPressed: busy ? null : _save,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BounceTap(
                  onTap: busy ? null : _test,
                  scale: 0.98,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.violet.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: c.violet.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (_testing)
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.wifi_tethering_rounded,
                            size: 16,
                            color: c.violet,
                          ),
                        const SizedBox(width: 7),
                        Text(
                          _testing ? '测试中…' : '测试连接',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.violet,
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
      ),
    );
  }
}

/// 显示「已配置 / 未配置 + 脱敏 Key」。
class _KeyStateTag extends StatelessWidget {
  const _KeyStateTag({required this.hasKey, required this.masked});

  final bool hasKey;
  final String masked;

  @override
  Widget build(BuildContext context) {
    final AppScheme c = context.scheme;
    final Color color = hasKey ? c.mintDeep : c.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasKey ? masked : '未配置',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
