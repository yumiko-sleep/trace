# 开发指南（Development Guide）

给未来接手这个仓库的你（或者几个月后的你自己）看的实操文档。
装环境、跑起来、改代码前要知道的约定、以及**踩过的坑**都在这。

---

## 一、环境要求

| 项 | 版本 / 位置（本文档作者的机器） |
| --- | --- |
| Flutter | 3.47.6 stable（`F:\dev\flutter`，bin 已加入用户级 PATH） |
| Dart SDK | 随 Flutter 自带（pubspec 约束 `>=3.4.0 <4.0.0`） |
| Android SDK | `F:\Android\Sdk`（platform-tools / cmdline-tools / platforms android-35 与 android-36 / build-tools 36.0.0） |
| JDK | Android Studio 自带 JBR（`F:\AndroidStudio\jbr`，构建时请设置 `JAVA_HOME`） |
| Gradle / AGP / Kotlin | Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0（wrapper 与插件版本已锁在仓库里） |
| 真机 | 一加 PKK110（Android 16），包名 `com.trace.app.trace` |

首次拉代码后：

```bash
flutter pub get
flutter analyze
flutter test
flutter run                      # 调试
flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 二、中国大陆网络环境

仓库里已经预置好镜像，国内网络可直接构建：

- `android/settings.gradle.kts` / `android/build.gradle.kts`：阿里云 Maven（google / central / gradle-plugin / public）优先，官方源兜底
- `android/gradle/wrapper/gradle-wrapper.properties`：Gradle 发行版走腾讯云镜像
- `pubspec.yaml` 末尾：`hooks.user_defines.sqlite3.url_pattern` 把 SQLite 原生库的下载指向 GitHub 加速镜像（**sha256 校验依然生效**）

如果某天你的网络能直连官方源，把这些镜像改回官方地址即可（`PUB_HOSTED_URL`、`FLUTTER_STORAGE_BASE_URL` 两个环境变量也是同理）。

---

## 三、代码组织与约定

```
lib/
├── core/        theme（配色 / 字体 / 动效曲线）· router · utils · widgets（通用组件）
├── data/        db（Drift 表与生成代码）· dao · models · repositories · providers · services · seed
└── features/    每个板块自带 domain / providers / presentation，互不越层
```

四条硬约定：

1. **UI 只依赖 Repository**，不直接碰 DAO；跨板块复用走 Provider。
2. **「某一天」统一归一化到当天 00:00**（`DayUtils.dayStart`），时间戳一律 UTC 存储。
3. **枚举一律 `intEnum` 存整数**（`lib/data/models/enums.dart`），文案在枚举扩展里。
4. **颜色只能从调色板取**：`final AppScheme c = context.scheme;` 然后 `c.ink` / `c.card` / `c.tasks`。
   不要在 Widget 里写死 `Colors.white` / 十六进制色值（渐变头部的白色叠层除外），
   否则切深色模式或换配色时那一块会「不跟着变」。
   新增/调整配色只需改 `lib/core/theme/app_scheme.dart` 一个文件。

### 动效约定

- 页面内容用 `SectionScaffold` 自带的错峰入场（`FadeSlideIn`，前 6 块递增延迟、位移 6%）。
- 统计数字用 `AnimatedCount`，进度环用 `GradientRing`（自带补间），图表过渡用 widget 上的 `duration/curve`。
- 底部弹窗统一用 `core/widgets/sheet_form.dart` 里的 `SheetLabel / SheetField / SheetChoice`，
  结构固定为「固定头部 + 可滚动表单（`Flexible` + `SingleChildScrollView`）+ 固定底部按钮」。
- **不要在弹窗里用 `autofocus: true`**：入场 + 键盘弹起 + 窗口 resize 挤在同一帧会明显掉帧，
  改成延迟 ~340ms 再 requestFocus。

---

## 四、改数据库

`lib/data/db/tables.dart` 改动后必须重新生成代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

⚠️ **`drift_dev` 必须 ≥ 2.35.1**。用 2.31 时它的 analyzer 3.12 与 Dart 3.13 不匹配，
生成的 `.g.dart` 会**缺枚举 import、完全不生成外键**（cascade / setNull 全部静默失效）。

---

## 五、测试

```bash
flutter analyze     # 必须 0 问题（CI 会卡这一步）
flutter test        # 当前 194 个用例
```

写 Widget 测试时注意三件事（都踩过）：

1. **不要用 `pumpAndSettle`**：加载态 `CircularProgressIndicator` 是无限动画、
   `TextField` 的光标计时器也会一直跑，会直接超时挂死。用**有界 pump 循环**（例如 8~12 次 × 120ms）。
2. 必须把 `appDatabaseProvider` override 成 `AppDatabase.memory()`，
   否则会卡在 `path_provider` 上拿不到目录。
3. 每个用例结尾要 `await tester.pumpWidget(const SizedBox()); await tester.pump(const Duration(seconds: 1));`，
   否则 drift 取消查询流订阅时排的计时器会触发 “A Timer is still pending...”。

另外：测试视口只有 600px 高，折叠线以下的内容要先 `ensureVisible` 再点（`tapAt` 这类小工具就是干这个的）。

---

## 六、发布签名

仓库**不含**任何密钥。签名配置读的是 `android/key.properties`（已在 `.gitignore` 里）：

```properties
storeFile=trace-release.jks      # 相对 android/app/
storePassword=（见你的密码管理器）
keyAlias=trace
keyPassword=（同上）
```

- 没有 `key.properties` 时会自动退回 debug 签名，所以新克隆的仓库依然能 `flutter build`。
- **`android/app/trace-release.jks` 与 `android/key.properties` 必须自己备份**：
  丢了就没法给已上架的应用发更新（只能换包名重发）。
- ⚠️ 换签名后**无法覆盖安装**：Android 会拒绝签名不一致的更新，
  必须先在设备上卸载旧版本（本地数据会被清空）再安装。
  **卸载前先在 App 里「设置 → 数据备份 → 导出备份」**，装好新包后再导入（见下一节）。
- 想核对产物签名：

```bash
$env:JAVA_HOME='F:\AndroidStudio\jbr'
& "F:\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

CI 里若要自动出签名包，在仓库 Secrets 配好 `ANDROID_KEYSTORE_BASE64`、
`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` 即可
（`.github/workflows/ci.yml` 里已经写好读取逻辑）。

---

## 七、数据备份 / 恢复

App 里的入口：**设置 → 数据备份 → 导出备份 / 导入备份**。

- 备份是一个 zip：`data.json`（10 张表的全部内容）+ `images/`（日记配图本体）。
  表内容直接用 drift 生成的 `toJson()` / `fromJson()` 序列化（枚举存整数、时间存 Unix 毫秒），
  所以以后给表加字段，只要重跑 build_runner，备份结构自动跟上，不用维护字段映射。
- **导出**走系统「另存为」（Android 的 SAF，**不需要任何存储权限**）。
  请选**下载**目录：那是公共存储，卸载 App 不会动它；存进 App 私有目录才会被卸载清掉。
- **导入**走系统文件选择器选 `trace_backup_*.zip`。确认弹窗会先把「要恢复什么」念一遍，
  确认后在**一个事务**里「清空 10 张表 → 全量写入」：失败整体回滚，不会出现导一半的脏数据。
  恢复期间临时 `PRAGMA foreign_keys = OFF`（父目标可能排在子目标后面、任务的 goalId 可能先写进来），
  写完立刻恢复 `ON`——级联删除依赖它。
- 配图在备份里**只存文件名**（绝对路径含包名，换机 / 重装就失效），导入时按当前设备的私有目录拼回去。
  先写图片、再写数据库：万一数据库回滚，最多留下几张没人引用的图（用「配图文件维护」清掉），
  不会出现「日记引用的图不见了」。
- 导入会覆盖**设置**（主题 / AI 服务商 / 模型），但**不覆盖 API Key**：
  Key 只存在系统安全存储里，既进不了数据库，也不该明文写进备份文件。导入后需自己重填一次。
- ⚠️ **换正式签名前请先导出**：卸载旧包会清空 App 私有数据（数据库 + 配图），
  备份 zip 放在下载目录则不受影响。

相关文件：`lib/data/services/backup/`（`trace_backup.dart` 格式定义 · `backup_codec.dart` 数据库 ⇄ JSON ·
`backup_service.dart` 打包与恢复）、`lib/features/settings/presentation/widgets/backup_card.dart`。
系统文件对话框被抽象成 `BackupFileGateway`，测试里换成内存替身，不会真的弹对话框。

---

## 八、AI 复盘相关

- 支持任何 OpenAI 兼容 `/chat/completions` 的服务商，设置页可改 baseUrl / 模型名；
  默认 DeepSeek + `deepseek-v4-pro`。
- API Key 走 `flutter_secure_storage`（Android Keystore / iOS Keychain），**不进数据库、不进仓库**。
- 想接入不兼容 OpenAI 协议的服务商（Gemini / Claude）：写一个 `implements AiProvider` 的类，
  在 `lib/data/services/ai/ai_provider_factory.dart` 里注册一行，复盘流程不用改。
- 模型返回的解析是容错的（代码块 / 别名键 / 纯文本都能吃），
  换模型后如果格式跑偏，先看 `lib/features/ai_review/domain/ai_review_report.dart` 的别名表。
