import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/ai_review/domain/ai_review_report.dart';

void main() {
  group('结构化 JSON 解析', () {
    test('标准返回', () {
      final AiReviewReport r = AiReviewReport.parse(
        '{"headline":"还行的一天","good":["任务 3/5"],"improve":["屏幕 200 分钟"],'
        '"tomorrow":["21:30 收手机"],"trend_insights":["入睡推迟 30 分钟"]}',
        model: 'deepseek-v4-pro',
      );

      expect(r.parsed, isTrue);
      expect(r.headline, '还行的一天');
      expect(r.good, <String>['任务 3/5']);
      expect(r.improve, <String>['屏幕 200 分钟']);
      expect(r.tomorrow, <String>['21:30 收手机']);
      expect(r.trendInsights, <String>['入睡推迟 30 分钟']);
      expect(r.itemCount, 4);
      expect(r.model, 'deepseek-v4-pro');
      expect(r.isEmpty, isFalse);
    });

    test('带代码块围栏和前后废话也能解析', () {
      final AiReviewReport r = AiReviewReport.parse(
        '好的，这是你的复盘：\n```json\n'
        '{"headline":"ok","good":["a"],"improve":["b"],"tomorrow":["c"]}\n'
        '```\n希望对你有帮助！',
      );
      expect(r.parsed, isTrue);
      expect(r.headline, 'ok');
      expect(r.good, <String>['a']);
    });

    test('键名别名 + 对象数组 + 单字符串都能吃', () {
      final AiReviewReport r = AiReviewReport.parse(
        '{"summary":"总结一下","highlights":[{"title":"早睡","detail":"23:00 就睡了"}],'
        '"problems":"屏幕时间超标","next_steps":["明天压到 120 分钟"],'
        '"trends":["阅读时长 7 天有 4 天为 0"]}',
      );
      expect(r.parsed, isTrue);
      expect(r.headline, '总结一下');
      expect(r.good, <String>['早睡：23:00 就睡了']);
      expect(r.improve, <String>['屏幕时间超标']);
      expect(r.tomorrow, <String>['明天压到 120 分钟']);
      expect(r.trendInsights, <String>['阅读时长 7 天有 4 天为 0']);
    });

    test('中文键名与大小写不敏感', () {
      final AiReviewReport r = AiReviewReport.parse(
        '{"一句话总结":"今天不错","Good":["完成任务"],"需要改进的":["睡太晚"],"明天建议":["早点睡"]}',
      );
      expect(r.parsed, isTrue);
      expect(r.headline, '今天不错');
      expect(r.good, <String>['完成任务']);
      expect(r.improve, <String>['睡太晚']);
      expect(r.tomorrow, <String>['早点睡']);
    });
  });

  group('纯文本兜底', () {
    test('按小标题切段', () {
      const String text = '今天整体还行，但晚上拖太久\n'
          '今天做得好的\n'
          '- 任务完成 4/5\n'
          '- 阅读 25 分钟\n'
          '需要改进的\n'
          '- 屏幕时间 260 分钟\n'
          '明天建议\n'
          '1. 21:30 前收手机\n'
          '2. 把难的事放上午\n'
          '趋势\n'
          '- 入睡时间从 23:10 推到 00:40';

      final AiReviewReport r = AiReviewReport.parse(text);
      expect(r.parsed, isTrue);
      expect(r.headline, '今天整体还行，但晚上拖太久');
      expect(r.good, <String>['任务完成 4/5', '阅读 25 分钟']);
      expect(r.improve, <String>['屏幕时间 260 分钟']);
      expect(r.tomorrow, <String>['21:30 前收手机', '把难的事放上午']);
      expect(r.trendInsights, <String>['入睡时间从 23:10 推到 00:40']);
      expect(r.rawText, text);
    });

    test('完全无法结构化时保留原文', () {
      const String text = '抱歉，我无法完成这个请求。';
      final AiReviewReport r = AiReviewReport.parse(text);
      expect(r.parsed, isFalse);
      expect(r.rawText, text);
      expect(r.isEmpty, isFalse, reason: '有原文就不算空');
      expect(r.itemCount, 0);
    });

    test('空返回判为空', () {
      expect(AiReviewReport.parse('   ').isEmpty, isTrue);
    });
  });

  group('存取往返', () {
    test('encode → decode 保持一致', () {
      const AiReviewReport original = AiReviewReport(
        headline: '标题',
        good: <String>['g1'],
        improve: <String>['i1'],
        tomorrow: <String>['t1'],
        trendInsights: <String>['d1'],
        parsed: true,
        model: 'deepseek-v4-pro',
      );

      final AiReviewReport back = AiReviewReport.decode(original.encode());
      expect(back.parsed, isTrue);
      expect(back.headline, '标题');
      expect(back.good, <String>['g1']);
      expect(back.improve, <String>['i1']);
      expect(back.tomorrow, <String>['t1']);
      expect(back.trendInsights, <String>['d1']);
      expect(back.model, 'deepseek-v4-pro');
    });

    test('原样文本存进库也能读回来', () {
      const String stored = '这不是 JSON，只是模型啰嗦了一段话。';
      final AiReviewReport back = AiReviewReport.decode(stored);
      expect(back.parsed, isFalse);
      expect(back.rawText, stored);
    });

    test('toJson 里保留了原始文本（解析失败时）', () {
      final AiReviewReport r = AiReviewReport.parse('随便说点什么');
      final Map<String, dynamic> json =
          jsonDecode(r.encode()) as Map<String, dynamic>;
      expect(json['parsed'], isFalse);
      expect(json['raw_text'], '随便说点什么');
    });
  });
}
