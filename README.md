# 轨迹 Trace

[![CI](https://github.com/yumiko-sleep/trace/actions/workflows/ci.yml/badge.svg)](https://github.com/yumiko-sleep/trace/actions/workflows/ci.yml)

> 记录每一天，看见成长的轨迹。

**轨迹 Trace** 是一个**由个人独立开发并完全开源**的个人成长管理 App。
它把「任务 · 目标 · 日记 · 数据 · 日志」五件事收进一个干净整洁的界面，
并用具备视觉能力的 AI 帮你每天做一次复盘总结。

- 👤 **作者 / 维护者：yumiko不想睡**
- 📱 平台：Android 优先，iOS 同步支持（Flutter 一套代码）
- 🎨 风格：两套配色（薄荷绿蓝 / 樱花粉白）× 浅色 / 深色，动效细腻
- 🔓 协议：MIT，完全开源，可自由使用与二次开发
- 🆓 价格：完全免费，无内购、无广告、无账号体系
- 📦 直接安装：[最新 Release](https://github.com/yumiko-sleep/trace/releases/latest) 下载 APK（安卓直装，见下方「下载与安装」）

---

## 一、功能总览

| 板块 | 内容 |
| --- | --- |
| **今日任务** | 今日待办列表，增 / 删 / 改 / 勾选完成，可关联到「目标」 |
| **目标** | 今日目标 / 今年目标 / 人生目标，支持进度、截止日期、状态 |
| **日记** | 文字 + 多张图片 + 心情标签，日期自动记录 |
| **数据** | 睡眠时间、起床时间、屏幕使用时长、饮食热量、阅读时长，并支持自定义数据项；周 / 月 / 年趋势图表 |
| **日志** | 学习日志（学习计划 + 今日记录）、训练日志（训练计划 + 今日记录）、每日复盘总结 |
| **AI 复盘** | 把当日全部数据（任务 / 目标 / 日记 / 数据趋势 / 日志）打包成结构化 JSON 交给模型，生成“今天做得好的 / 需要改进的 / 明天建议 / 趋势洞察”；可取消、可查看每次发送的原始数据 |
| **备份 / 恢复** | 一键把全部数据（含日记配图）导出成一个 zip 存到手机「下载」目录，重装或换机后导入即完整恢复（设置页 → 数据备份） |

## 二、下载与安装（安卓）

不用装 Flutter、不用自己编译，下载 APK 直接安装即可。

1. 打开 **[Releases 页面](https://github.com/yumiko-sleep/trace/releases/latest)**，
   在最新版本的 **Assets** 里下载 `app-release.apk`（用手机浏览器直接打开这个链接下载最省事）。
2. 点开下载好的文件安装。系统会拦一下，提示「**禁止安装未知应用**」：
   去「设置 → 应用 → 特殊应用权限 → 安装未知应用」，找到你刚才用来打开 APK 的那个应用
   （浏览器或「文件管理」），把开关打开，再回到安装界面点「安装」。
3. 装好打开就能用：默认是薄荷绿蓝浅色主题，任务 / 目标 / 日记 / 数据 / 日志全部存在本机。
4. **想让 AI 复盘可用，需要自己填一个 API Key**（不填也能用，只是 AI 复盘那块不可用）：
   底部导航「设置 → AI 复盘」→ 选服务商（默认 DeepSeek）→ 粘贴自己的 Key → 点「测试连接」。
   Key 只保存在手机的系统安全存储里（Android Keystore），不写进代码、不进数据库，
   也不会随备份文件导出。

### 国内用户：直连下载卡住怎么办

大陆网络直连 GitHub 时，常见的症状是页面一直转圈，或者 APK 下载**卡在 0%、速度只有几 KB/s**——
文件名和体积能正常显示，但数据传不动。这是国内访问 GitHub 的常见问题，**不是安装包有问题**。

办法很简单：给链接套一个国内加速源，**在原始链接前面加上 `https://gh-proxy.com/` 即可**。

```text
原始链接
https://github.com/yumiko-sleep/trace/releases/download/v0.2.1/app-release.apk

加速后（复制到手机浏览器打开）
https://gh-proxy.com/https://github.com/yumiko-sleep/trace/releases/download/v0.2.1/app-release.apk
```

加速源只是替你转发 GitHub 的文件流，**下载到的 APK 与直链完全一致**
（同一个文件，可以自己对比 SHA-256 验证）。链接里的 `v0.2.1` 换成你要装的版本号（tag）即可；
有加速源之后，上面第 1~2 步的流程完全一样。

补充几点：

- **升级**：以后有新版本，去同一个页面下载新 APK 直接覆盖安装即可，数据保留。
- **换手机 / 重装**：先用 App 内「设置 → 数据备份 → 导出备份」把数据（含日记配图）
  存成一个 zip 放到「下载」目录，新设备装好后「导入备份」就能完整还原。
- **包信息**：包名 `com.trace.app.trace`，最低 Android 6.0（API 23），release 包只带 arm64 架构。
- 从 **v0.2.0** 起，Release 里的 APK 由正式 keystore 签名（指纹见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)），
  可以正常覆盖升级。

## 三、技术栈

| 用途 | 选型 |
| --- | --- |
| 框架 | Flutter 3.x + Dart 3 |
| 状态管理 | flutter_riverpod |
| 路由 | go_router（StatefulShellRoute 底部导航） |
| 本地数据库 | Drift 2.x（SQLite，已接入） |
| 图表 | fl_chart（渐变折线 + 目标线 + 触摸提示，切换带过渡） |
| 主题 | 两套品牌配色（薄荷绿蓝 / 樱花粉白）× 浅色 / 深色共 6 种组合；`ThemeExtension` 调色板驱动，设置页实时切换 |
| 图片 | image_picker（阶段 4 接入） |
| AI | 自建 provider 抽象层（OpenAI 兼容协议）：默认 DeepSeek `deepseek-v4-pro`，可切智谱 GLM / OpenAI / 任意自建服务 |

## 四、目录结构

```
lib/
├── main.dart                  # 入口
├── app.dart                   # MaterialApp / 主题 / 路由
├── core/
│   ├── theme/                 # app_scheme（4 套配色）× app_theme（ThemeExtension 调色板）· 字体 · 动效曲线
│   ├── router/                # go_router 配置 + 路由常量
│   ├── utils/                 # day_utils：日期归一化、时间点/时长格式化
│   └── widgets/               # 通用组件（渐变背景、卡片、渐变按钮、环形进度…）
├── data/                      # ★ 数据层（阶段 1）
│   ├── db/
│   │   ├── tables.dart        # 10 张表的定义
│   │   ├── app_database.dart  # Drift 数据库（@DriftDatabase）+ 建库与种子
│   │   ├── app_database.g.dart# 生成代码（build_runner 产出，勿手改）
│   │   └── connection.dart    # 落盘连接（App 私有目录）
│   ├── models/                # enums（目标/心情/数据项类型…）、stats（统计模型）
│   ├── seed/                  # built_in_metrics：5 个内置数据项
│   ├── dao/                   # 7 个 DAO：只写 SQL，不含业务判断
│   ├── repositories/          # 7 个 Repository：UI 唯一入口
│   ├── providers/             # Riverpod 依赖注入
│   └── services/              # 独立服务：image_storage、backup/（导出与导入）、ai/（provider 抽象 + OpenAI 兼容实现 + Key 安全存储）
└── features/
    ├── shell/                 # 底部导航外壳（玻璃拟态导航条）
    ├── home/                  # 主页：五大板块入口
    ├── tasks/                 # 板块 1 今日任务
    ├── goals/                 # 板块 2 目标
    ├── diary/                 # 板块 3 日记
    ├── metrics/               # 板块 4 数据
    ├── journal/               # 板块 5 日志
    ├── ai_review/             # AI 每日复盘（结构化上下文 + 结果解析 + 报告展示）
    └── settings/              # 设置（外观主题 / AI 供应商 / 配图文件维护 / 数据备份与恢复）

docs/                          # 开发指南（环境、约定、踩过的坑）
.github/workflows/ci.yml       # CI：analyze + test（打 tag 时额外构建 APK）
```

### 数据层分层约定

```
UI (features/)  →  Repository  →  DAO  →  Drift / SQLite
```

- **UI 只依赖 Repository**，不直接碰 DAO 或数据库。
- **DAO 只写 SQL**，不含业务判断。
- **Repository** 负责业务语义：如「今日任务统计」「同一天同一指标覆盖写入」「日记+图片同事务保存」。


## 五、本地运行

完整的搭建步骤、镜像配置、代码约定与「踩过的坑」都在 **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**。
快速开始：

```bash
git clone https://github.com/yumiko-sleep/trace.git
cd trace
flutter pub get
flutter analyze && flutter test   # 应当 0 问题、全部通过
flutter run                       # 连上真机/模拟器后直接跑
```

打包 Android 安装包：
flutter build apk --release --split-per-abi
# 产物：build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### 中国大陆网络环境说明

`android/settings.gradle.kts`、`android/build.gradle.kts` 与
`android/gradle/wrapper/gradle-wrapper.properties` 已经预置了国内镜像
（阿里云 Maven + 腾讯 Gradle 发行版），在国内网络下可直接构建，无需代理。
若你的网络可以直连官方源，把官方仓库放回前面即可。

`pubspec.yaml` 末尾的 `hooks.user_defines.sqlite3.url_pattern` 把 SQLite 原生库的
下载源改成了 GitHub 加速镜像（下载内容与官方一致，sha256 校验依然生效）。
如果你的网络能直连 GitHub，把这一段删掉即可。

## 六、测试

```bash
flutter analyze        # 静态分析
flutter test           # 单元测试（当前 194 个用例）
dart run build_runner build   # 改动 data/db/tables.dart 后重新生成代码
```

测试用例覆盖：10 张表的增删改查、5 个内置数据项的种子数据、
唯一约束（同一天同一指标只有一条）、外键级联（删目标置空任务关联、
删日记级联删图片、删数据项级联删记录）、响应式流（watch），
以及板块页的交互（新建任务/目标、勾选、左滑删除+撤销、分类切换、进度联动，
日记的写作-保存-时间线-删除恢复全流程，数据的每日录入、自定义数据项、
趋势区间切换与达标率 / 连续天数统计，日志的计划-记录-复盘全流程与学习/训练隔离，
AI 复盘的结构化上下文（任务/目标/日记/数据趋势表格/日志）、模型返回的容错解析
（JSON / 代码块 / 别名键 / 纯文本兜底）、HTTP 错误与超时的中文提示、
无 Key 时的引导与失败回填，主题（四套配色的唯一性与对比度方向、
配色与亮度切换后落库并全局生效），以及备份 / 恢复（10 张表完整往返、外键与可空枚举不丢、
导入先清空再写入、配图路径跨设备重建、损坏文件与非本 App 备份被明确拒绝、
导出取消不算失败）。


## 七、开发路线图

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 0 | 项目骨架、渐变主题、五板块导航 | ✅ 完成（真机验证通过） |
| 1 | Drift 数据层（10 张表 / 7 个 DAO / 7 个 Repository / 种子数据 / 71 个单测） | ✅ 完成 |
| 2 | 今日任务（列表 / 新建编辑 / 勾选 / 左滑删除 + 撤销 / 筛选 / 顺延） | ✅ 完成 |
| 3 | 目标（今日 / 今年 / 人生三级、进度环、截止倒计时、与任务联动） | ✅ 完成 |
| 4 | 日记（文字 + 多图 + 心情 + 时间线 + 大图预览） | ✅ 完成 |
| 5 | 数据记录（每日一屏录入 / 补录 / 自定义数据项）+ fl_chart 趋势图表（周月年、目标线、达标率、连续天数） | ✅ 完成 |
| 6 | 日志（学习 / 训练计划 + 每日记录 + 时长统计 + 复盘） | ✅ 完成 |
| 7 | AI 复盘（provider 抽象层 + 结构化上下文 + 趋势数字表格 + 三分段报告 + Key 安全存储） | ✅ 完成 |
| 8 | 动效润色（✅）、深色模式 + 双配色（✅）、孤儿图片清理（✅）、文档与 CI（✅）、正式签名（✅）、数据备份 / 恢复（✅） | ✅ 完成 |
| 发布 | **v0.2.0**：首个公开 Release —— 源码 + 正式签名 APK + 安装说明 | ✅ 已发布 |
| 发布 | **v0.2.1**：分段切换交叉淡入 · 弹窗入场时长统一 · 深色模式弹窗与输入框修复 | ✅ 已发布 |

## 八、隐私与密钥

- 所有数据默认保存在本机数据库，不会自动上传。
- 调用 AI 时才会把你选择的数据发送给对应模型服务商。
- 触发方式：只有你在「AI 每日复盘」页手动点「生成今天的复盘」才会发起请求；
  发送内容是结构化 JSON（任务 / 目标 / 日记文字 / 数据 7 天数字表格 / 日志），
  当前版本只发文字，日记图片仅统计数量、不上传图片。
- 每次生成都会把「发给模型的数据」原样存进本地快照，界面上可随时查看。
- 生成过程中可随时「取消」，会真实断开这次的网络请求（不再继续消耗额度）；
  App 被杀 / 请求中断留下的「生成中」记录会在下次进页时自动标为失败。
- 速度建议：想快就用非推理模型（如 deepseek-chat）；推理模型的思考过程会明显拉长耗时。
- 「设置 → 配图文件维护」可扫描并清理日记残留的图片文件
  （删日记时为支持「撤销」而刻意保留的那部分），清理前会先扫描并让你确认。
- 「设置 → 数据备份」导出的 zip **是明文的**（`data.json` + 日记配图原图），
  保存在你选择的位置（建议手机「下载」目录，卸载 App 不会删）。
  这个文件等同于你的全部数据，请自己保管好；导入时会先清空当前数据再写入。
  备份里**不含 API Key**（Key 只存在系统安全存储里，不进数据库）。
- API Key 使用系统安全存储（flutter_secure_storage：Android Keystore / iOS Keychain）
  保存在本机，**不会**写入代码、数据库或提交到仓库。
- 仓库的 `.gitignore` 已覆盖 `.env`、`*.jks`、`*.keystore`、`key.properties`、
  `local.properties`、`google-services.json` 等敏感文件。
- 发布签名：正式 keystore 只存在本地（`android/key.properties` + `android/app/trace-release.jks`，
  均不入仓库）。没有它时构建会自动退回 debug 签名，方便任何人克隆后直接打包。
  注意：换签名后无法覆盖安装，必须先在设备上卸载旧版本（本地数据会清空）；
  卸载前记得先用「设置 → 数据备份」导出一份，重装后再导入。

## 九、关于作者

这是一个**个人开源项目**，由 **yumiko不想睡** 独立设计与开发，代码全部公开，
欢迎任何人学习、使用、修改和分发（遵循 MIT 协议）。

如果你觉得它有用，欢迎 Star ⭐；有问题或想法，欢迎提 Issue。

## 十、开源协议

本项目采用 [MIT License](LICENSE)。

```
Copyright (c) 2026 yumiko不想睡
```

## 十一、贡献

欢迎 Issue 与 PR。提交前请执行：

```bash
dart format .
flutter analyze
flutter test
```

CI（`.github/workflows/ci.yml`）会对每个 PR 跑同样的两道检查；
打 tag 或手动触发时还会额外构出 arm64 的 release APK。
