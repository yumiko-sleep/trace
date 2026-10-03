import '../models/enums.dart';

/// 一个内置数据项的定义（不含数据库自增 id）。
class BuiltInMetric {
  const BuiltInMetric({
    required this.key,
    required this.name,
    required this.unit,
    required this.valueType,
    required this.colorHex,
    required this.iconKey,
    required this.sortOrder,
    this.targetValue,
  });

  /// 稳定标识，供代码里引用（不要随便改）
  final String key;
  final String name;
  final String unit;
  final MetricValueType valueType;

  /// ARGB 颜色
  final int colorHex;
  final String iconKey;

  /// 单位：clock 类型为空，duration 类型为分钟
  final double? targetValue;
  final int sortOrder;
}

/// 5 个内置数据项。
///
/// 用户可以在「数据」板块继续添加自定义数据项，
/// 它们和内置项走完全相同的表结构与图表逻辑。
const List<BuiltInMetric> kBuiltInMetrics = <BuiltInMetric>[
  BuiltInMetric(
    key: 'sleep_time',
    name: '入睡时间',
    unit: '',
    valueType: MetricValueType.clock,
    colorHex: 0xFF8B6CF7,
    iconKey: 'bedtime',
    sortOrder: 0,
  ),
  BuiltInMetric(
    key: 'wake_time',
    name: '起床时间',
    unit: '',
    valueType: MetricValueType.clock,
    colorHex: 0xFF5B7CFA,
    iconKey: 'wake',
    sortOrder: 1,
  ),
  BuiltInMetric(
    key: 'screen_time',
    name: '屏幕使用',
    unit: '分钟',
    valueType: MetricValueType.duration,
    colorHex: 0xFF2E9BF7,
    iconKey: 'screen',
    sortOrder: 2,
    targetValue: 180,
  ),
  BuiltInMetric(
    key: 'calories',
    name: '饮食热量',
    unit: 'kcal',
    valueType: MetricValueType.number,
    colorHex: 0xFF22C1DC,
    iconKey: 'calories',
    sortOrder: 3,
  ),
  BuiltInMetric(
    key: 'reading_time',
    name: '阅读时长',
    unit: '分钟',
    valueType: MetricValueType.duration,
    colorHex: 0xFF3DDC97,
    iconKey: 'reading',
    sortOrder: 4,
    targetValue: 30,
  ),
];

/// 内置数据项的 key 常量，避免代码里散落魔法字符串。
class BuiltInMetricKeys {
  const BuiltInMetricKeys._();

  static const String sleepTime = 'sleep_time';
  static const String wakeTime = 'wake_time';
  static const String screenTime = 'screen_time';
  static const String calories = 'calories';
  static const String readingTime = 'reading_time';
}
