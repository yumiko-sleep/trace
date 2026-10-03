/// 一次 AI 请求的取消令牌。
///
/// 上层点「取消」时，网络层会**主动断开连接**（关闭当次请求独占的 http.Client），
/// 而不是只把界面切回空闲、让请求在后台跑完继续烧 token。
class AiCancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  /// 订阅取消事件；如果已经取消了会立即回调。
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final List<void Function()> listeners =
        List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final void Function() listener in listeners) {
      listener();
    }
  }

  /// 在发起请求前 / 解析结果前调用：已取消就直接抛出去。
  void throwIfCancelled() {
    if (_cancelled) throw const AiCancelledException();
  }
}

/// 用户主动取消（不是错误，界面不该显示成失败原因）。
class AiCancelledException implements Exception {
  const AiCancelledException();

  @override
  String toString() => '用户已取消这次生成';
}
