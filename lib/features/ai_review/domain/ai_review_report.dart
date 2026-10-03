import 'dart:convert';

/// ============================================================
/// 模型返回的复盘报告。
///
/// 约定模型返回严格 JSON：
/// ```json
/// {"headline":"…","good":["…"],"improve":["…"],"tomorrow":["…"],"trend_insights":["…"]}
/// ```
/// 但真实世界不保证格式，所以这里做容错：
/// 1. 去 Markdown 代码块 → 取第一个 `{` 到最后一个 `}` → jsonDecode；
/// 2. 键名支持一堆别名（good / highlights / 今天做得好的…）；
/// 3. 值是字符串或对象数组都能吃；
/// 4. 彻底解析不了就退化成纯文本（[parsed] = false），界面原样展示，
///    绝不因为格式问题丢掉用户已经花掉的 token。
/// ============================================================
class AiReviewReport {
  const AiReviewReport({
    this.headline = '',
    this.good = const <String>[],
    this.improve = const <String>[],
    this.tomorrow = const <String>[],
    this.trendInsights = const <String>[],
    this.rawText = '',
    this.parsed = false,
    this.model = '',
  });

  /// 一句话总结
  final String headline;

  /// 今天做得好的
  final List<String> good;

  /// 需要改进的
  final List<String> improve;

  /// 明天建议
  final List<String> tomorrow;

  /// 数据趋势解读
  final List<String> trendInsights;

  /// 原始返回（解析失败时用来兜底展示）
  final String rawText;

  /// 是否成功解析成结构化报告
  final bool parsed;

  final String model;

  bool get isEmpty =>
      headline.trim().isEmpty &&
      good.isEmpty &&
      improve.isEmpty &&
      tomorrow.isEmpty &&
      trendInsights.isEmpty &&
      rawText.trim().isEmpty;

  int get itemCount =>
      good.length + improve.length + tomorrow.length + trendInsights.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'headline': headline,
        'good': good,
        'improve': improve,
        'tomorrow': tomorrow,
        'trend_insights': trendInsights,
        'parsed': parsed,
        if (model.isNotEmpty) 'model': model,
        if (!parsed) 'raw_text': rawText,
      };

  String encode() => jsonEncode(toJson());

  static const List<String> _headlineKeys = <String>[
    'headline',
    'summary',
    'one_liner',
    'conclusion',
    'overview',
    '一句话总结',
  ];
  static const List<String> _goodKeys = <String>[
    'good',
    'good_points',
    'highlights',
    'did_well',
    'achievements',
    'strengths',
    '今天做得好的',
    '做得好的',
  ];
  static const List<String> _improveKeys = <String>[
    'improve',
    'improvements',
    'to_improve',
    'problems',
    'issues',
    '需要改进的',
    '改进',
  ];
  static const List<String> _tomorrowKeys = <String>[
    'tomorrow',
    'tomorrow_suggestions',
    'suggestions',
    'next_steps',
    'advice',
    'action_items',
    '明天建议',
    '建议',
  ];
  static const List<String> _trendKeys = <String>[
    'trend_insights',
    'trends',
    'trend',
    'trend_analysis',
    'insights',
    '数据趋势',
    '趋势洞察',
  ];

  /// 解析模型返回。永远不抛异常。
  static AiReviewReport parse(String content, {String model = ''}) {
    final String text = content.trim();
    if (text.isEmpty) {
      return AiReviewReport(model: model);
    }

    final Map<String, dynamic>? json = _tryDecodeJson(text);
    if (json != null) {
      final AiReviewReport report = fromJson(json, model: model);
      if (!report.isEmpty || report.headline.isNotEmpty) {
        return report;
      }
    }

    // JSON 解析不出来：试试从纯文本 / Markdown 里抠三段
    final AiReviewReport fromText = _parsePlainText(text, model: model);
    if (fromText.parsed) return fromText;

    return AiReviewReport(rawText: text, parsed: false, model: model);
  }

  /// 从数据库里读回来（内容可能是报告 JSON，也可能是纯文本）。
  static AiReviewReport decode(String stored, {String model = ''}) =>
      parse(stored, model: model);

  static AiReviewReport fromJson(
    Map<String, dynamic> json, {
    String model = '',
  }) {
    return AiReviewReport(
      headline: _firstString(json, _headlineKeys),
      good: _stringList(_firstValue(json, _goodKeys)),
      improve: _stringList(_firstValue(json, _improveKeys)),
      tomorrow: _stringList(_firstValue(json, _tomorrowKeys)),
      trendInsights: _stringList(_firstValue(json, _trendKeys)),
      parsed: true,
      model: json['model'] as String? ?? model,
    );
  }

  static Map<String, dynamic>? _tryDecodeJson(String text) {
    final String cleaned = _stripFences(text);
    final int start = cleaned.indexOf('{');
    final int end = cleaned.lastIndexOf('}');
    final String candidate = start >= 0 && end > start
        ? cleaned.substring(start, end + 1)
        : cleaned;
    try {
      final Object? decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 忽略，交给纯文本兜底
    }
    return null;
  }

  static String _stripFences(String text) {
    String out = text.trim();
    if (out.startsWith('```')) {
      final int firstNewline = out.indexOf('\n');
      if (firstNewline > 0) out = out.substring(firstNewline + 1);
      final int lastFence = out.lastIndexOf('```');
      if (lastFence >= 0) out = out.substring(0, lastFence);
    }
    return out.trim();
  }

  static Object? _firstValue(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    // 忽略大小写再找一遍
    for (final MapEntry<String, dynamic> entry in json.entries) {
      for (final String key in keys) {
        if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
      }
    }
    return null;
  }

  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    final Object? value = _firstValue(json, keys);
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List && value.isNotEmpty) {
      return _stringList(value).join(' ').trim();
    }
    return value.toString().trim();
  }

  static List<String> _stringList(Object? value) {
    if (value == null) return const <String>[];
    if (value is String) {
      final String t = value.trim();
      return t.isEmpty ? const <String>[] : <String>[t];
    }
    if (value is Map) {
      final String joined = _mapToText(value);
      return joined.isEmpty ? const <String>[] : <String>[joined];
    }
    if (value is List) {
      final List<String> out = <String>[];
      for (final Object? item in value) {
        if (item == null) continue;
        if (item is String) {
          if (item.trim().isNotEmpty) out.add(item.trim());
        } else if (item is Map) {
          final String text = _mapToText(item);
          if (text.isNotEmpty) out.add(text);
        } else if (item is num || item is bool) {
          out.add('$item');
        }
      }
      return out;
    }
    return <String>[value.toString().trim()];
  }

  /// 把 `{"title":"…","detail":"…"}` 这类对象拼成一句人话。
  static String _mapToText(Map<dynamic, dynamic> map) {
    const List<String> preferred = <String>[
      'text',
      'content',
      'title',
      'point',
      'detail',
      'description',
      'advice',
      'suggestion',
      'reason',
    ];
    final List<String> parts = <String>[];
    for (final String key in preferred) {
      final Object? v = map[key];
      if (v is String && v.trim().isNotEmpty) parts.add(v.trim());
    }
    if (parts.isEmpty) {
      for (final Object? v in map.values) {
        if (v is String && v.trim().isNotEmpty) parts.add(v.trim());
      }
    }
    return parts.join('：');
  }

  // ---------------- 纯文本兜底 ----------------

  static AiReviewReport _parsePlainText(String text, {String model = ''}) {
    final List<String> lines = text
        .split('\n')
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList(growable: false);

    final List<String> good = <String>[];
    final List<String> improve = <String>[];
    final List<String> tomorrow = <String>[];
    final List<String> trend = <String>[];
    String headline = '';

    List<String>? current;
    for (final String line in lines) {
      final String plain = line.replaceAll(RegExp(r'[*#>`]'), '').trim();
      if (_matches(plain, <String>['做得好的', '亮点', 'good', 'did well'])) {
        current = good;
        continue;
      }
      if (_matches(plain, <String>['需要改进', '改进', '问题', 'improve', 'problem'])) {
        current = improve;
        continue;
      }
      if (_matches(plain, <String>['明天建议', '明天', '建议', 'tomorrow', 'next step'])) {
        current = tomorrow;
        continue;
      }
      if (_matches(plain, <String>['趋势', 'trend'])) {
        current = trend;
        continue;
      }
      final String item = plain.replaceFirst(
        RegExp(r'^[-•*\d\.、\)]+\s*'),
        '',
      );
      if (item.isEmpty) continue;
      if (current != null) {
        current.add(item);
      } else if (headline.isEmpty && item.length <= 60) {
        headline = item;
      }
    }

    final bool any = good.isNotEmpty ||
        improve.isNotEmpty ||
        tomorrow.isNotEmpty ||
        trend.isNotEmpty;
    if (!any) return AiReviewReport(rawText: text, parsed: false, model: model);

    return AiReviewReport(
      headline: headline,
      good: good,
      improve: improve,
      tomorrow: tomorrow,
      trendInsights: trend,
      rawText: text,
      parsed: true,
      model: model,
    );
  }

  static bool _matches(String line, List<String> keywords) {
    final String lower = line.toLowerCase();
    return keywords.any((String k) => lower.contains(k.toLowerCase()));
  }
}
