/// 全局枚举定义。
///
/// 这些枚举会被 Drift 以 `intEnum<T>()` 的方式存进数据库
/// （存整数，可读性和查询性能都优于存字符串）。
library;

/// 目标的时间尺度。
enum GoalCategory {
  /// 今日目标
  today,

  /// 今年目标
  thisYear,

  /// 人生目标
  life,
}

extension GoalCategoryX on GoalCategory {
  String get label => switch (this) {
        GoalCategory.today => '今日目标',
        GoalCategory.thisYear => '今年目标',
        GoalCategory.life => '人生目标',
      };

  String get description => switch (this) {
        GoalCategory.today => '今天就能推进的一小步',
        GoalCategory.thisYear => '今年想达成的结果',
        GoalCategory.life => '想成为的那个人',
      };
}

/// 目标状态。
enum GoalStatus {
  /// 进行中
  active,

  /// 已完成
  done,

  /// 已搁置
  paused,
}

extension GoalStatusX on GoalStatus {
  String get label => switch (this) {
        GoalStatus.active => '进行中',
        GoalStatus.done => '已完成',
        GoalStatus.paused => '已搁置',
      };
}

/// 日记心情。
enum Mood {
  happy,
  calm,
  neutral,
  sad,
  anxious,
}

extension MoodX on Mood {
  /// 用于界面展示的表情。
  String get emoji => switch (this) {
        Mood.happy => '😄',
        Mood.calm => '🙂',
        Mood.neutral => '😐',
        Mood.sad => '😔',
        Mood.anxious => '😤',
      };

  String get label => switch (this) {
        Mood.happy => '开心',
        Mood.calm => '平静',
        Mood.neutral => '一般',
        Mood.sad => '低落',
        Mood.anxious => '焦虑',
      };

  String get display => '$emoji $label';
}

/// 数据项的取值类型，决定界面用什么输入控件、图表怎么画。
enum MetricValueType {
  /// 普通数值（如热量 kcal）
  number,

  /// 时长（单位通常为分钟）
  duration,

  /// 时间点（如 23:30 睡觉 → 存成当天的分钟数 1410）
  clock,
}

extension MetricValueTypeX on MetricValueType {
  String get label => switch (this) {
        MetricValueType.number => '数值',
        MetricValueType.duration => '时长',
        MetricValueType.clock => '时间点',
      };
}

/// 日志类型：学习 / 训练。
enum JournalType {
  study,
  training,
}

extension JournalTypeX on JournalType {
  String get label => switch (this) {
        JournalType.study => '学习日志',
        JournalType.training => '训练日志',
      };
}

/// AI 复盘状态。
enum AiReviewStatus {
  /// 已触发、等待模型返回
  pending,

  /// 生成成功
  success,

  /// 生成失败（网络、额度、Key 无效等）
  failed,
}

extension AiReviewStatusX on AiReviewStatus {
  String get label => switch (this) {
        AiReviewStatus.pending => '生成中',
        AiReviewStatus.success => '已生成',
        AiReviewStatus.failed => '生成失败',
      };
}
