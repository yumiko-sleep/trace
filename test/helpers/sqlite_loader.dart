import 'dart:io';

/// 测试环境自检。
///
/// 说明：从 sqlite3 3.x 开始，原生库由 Dart 的构建钩子自动准备
/// （pub 里能看到 `native_toolchain_c` / `hooks` 这些依赖），
/// 因此不再需要像 sqlite3 2.x 那样手动调用 `open.overrideFor(...)`。
///
/// 如果将来在 Windows 上遇到
/// `Failed to load dynamic library 'sqlite3.dll'`，
/// 处理办法：
///   1. 先执行 `flutter clean && flutter pub get`，让构建钩子重新准备原生库；
///   2. 仍然不行时，把 `sqlite3.dll` 放到系统 PATH 能搜索到的目录，
///      或直接放到项目根目录（`flutter test` 的工作目录）。
void ensureSqliteAvailable() {
  if (Platform.isWindows) {
    // 目前无需额外操作：交给构建钩子 / 系统查找。
  }
}
