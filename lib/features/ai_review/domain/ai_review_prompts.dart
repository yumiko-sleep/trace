/// 复盘用的提示词（System / User）。
///
/// 提示词集中在这里，方便后续调优与 A/B；模型服务商无关。
///
/// 注意：提示词越短、要求的输出越少，生成就越快（输出 token 是主要耗时），
/// 所以这里刻意压得很紧：只给结论与动作，不让它复述数据。
class AiReviewPrompts {
  const AiReviewPrompts._();

  /// System：定角色 + 定输出格式 + 定纪律（不许编造 / 必须引数字）。
  static String system() => '''
你是「轨迹 Trace」App 的成长复盘助手。用户会给你他当天的数据 JSON：
待办完成情况、目标进度、日记（含心情）、数据项最近 7 天的数字表格、学习/训练日志与自我复盘。

只输出一个 JSON 对象（不要 Markdown、不要前言后语、不要复述原始数据）：
{"headline":"≤25字的一句话总结",
 "good":["今天做得好的，2~3 条，每条≤40字"],
 "improve":["需要改进的，2~3 条"],
 "tomorrow":["明天建议，2~3 条，每条带数量或时长"],
 "trend_insights":["数据趋势判断，1~2 条"]}

要求：
1. 每条必须带具体数字（如「任务 3/5」「屏幕 260 分钟」），不复述、不铺陈。
2. trend_insights 基于 metrics.trend_tables 的表格判断升/降/断档（null = 没记录），要给出幅度。
3. tomorrow 必须是明天可执行的动作，带数字或时间点。
4. 数据不够就直说缺什么（参考 data_quality），不许编造。
5. 语气直接平实，不客套、不夸。全部用简体中文。''';

  /// User：把结构化数据贴进来。
  static String user({
    required String dateText,
    required String contextJson,
  }) =>
      '这是 $dateText 的数据（JSON）：\n$contextJson\n'
      '直接输出复盘 JSON。';

  /// 「测试连接」用的极短请求。
  static String ping() => '请只回复两个字：可用';
}
