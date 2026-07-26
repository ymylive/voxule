# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

本仓库文档与代码注释均为中文，请保持中文交流与注释风格。

## 项目概览

voxlue「声音胶囊」—— iOS 26 / SwiftUI 应用（移动应用创新赛参赛作品）。核心闭环：录音 → 装裱 → 上锁埋下 → 条件满足显影 → 回放。三把锁（地点/时间/情绪）、三个收件人（自己/声音圈/公开）。

环境：Xcode 26.5 · Swift 6.2 · SwiftData + CloudKit · Swift Testing。

## 常用命令

```bash
# 包单元测试（108 测例，最常用的验证手段）
cd VoxlueKit && swift test

# 只跑单个测试 / 某个 suite
cd VoxlueKit && swift test --filter TriggerEngineTests

# App 构建 + 装模拟器 + 启动（推荐，一句搞定）
scripts/run-sim.sh              # 增量构建 + 装 + 启
scripts/run-sim.sh --fresh      # 卸载重装（清 NSUserDefaults / SwiftData）
scripts/run-sim.sh --build-only
DEVICE="iPhone 17 Pro" scripts/run-sim.sh

# 直接 xcodebuild —— 必须带 CODE_SIGNING_ALLOWED=NO（见下）
xcodebuild -project voxule/voxule.xcodeproj -scheme voxule \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build CODE_SIGNING_ALLOWED=NO

# UI 测试主循环
xcodebuild test -project voxule/voxule.xcodeproj -scheme voxule \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:voxuleUITests/voxuleUITests/testRecordBuryPlayMainLoop \
  CODE_SIGNING_ALLOWED=NO

# Cloudflare Worker（backend/agent-proxy/）
cd backend/agent-proxy && npm run typecheck   # tsc --noEmit
cd backend/agent-proxy && npm run dev / npm run deploy

# 临床措辞合规扫描（提交前跑，命中禁用词即失败）
scripts/check-clinical-words.sh
```

**模拟器构建为何免签名**：本机 SwiftPM 资源 bundle（VoxlueKit_VoxlueDesign.bundle 内字体）在 codesign 阶段会被拒为 "bundle format unrecognized"。`run-sim.sh` 已内置 `CODE_SIGNING_ALLOWED=NO`，仅限模拟器，不动工程配置，真机/CI 签名链路不受影响。

## 架构

### 分层：本地 SPM 包 VoxlueKit + App 壳层

- `VoxlueKit/`（本地 Swift Package，三个 library，绝大部分逻辑在这里，用 `swift test` 快速验证）
  - **VoxlueData** —— 模型层：`Capsule` / `Circle` / `Lock` / 枚举 / `CapsuleStore`（SwiftData 存取）/ `VoxlueModelContainer`
  - **VoxlueServices** —— 领域服务，依赖 VoxlueData：`AudioEngine`（录音/播放）、`TriggerEngine`（三把锁判定 + 显影推进）、`GeofenceScheduler`、`BackgroundTaskCoordinator`、`CircleService`（CKShare 声音圈）、`LiveActivityController`（灵动岛）、`Agent/`（`AgentGateway` / `IntelligenceService` / `SignalDistiller` —— 云端 agent 浮现闭环）
  - **VoxlueDesign** —— 设计系统，**独立包，不依赖 Data/Services**：Tokens（纸·墨·朱八色）/ Paper 组件 / Glass chrome / Motion / 自定义字体（随 resource bundle 打包，首次使用经 CoreText 注册）
- `voxule/voxule/` —— App 壳层与视图（SwiftUI），四标签：首页 / 样片墙 / 地图 / 我
- `voxule/VoxlueWidget/` —— 灵动岛 widget 源文件（Xcode target 尚未建，需开发者环境手动新建）
- `backend/agent-proxy/` —— 唯一自建服务端：Cloudflare Worker（TypeScript），极薄无状态大模型转发代理

### 依赖注入与测试模式

- **MV 模式，无 ViewModel**：服务是 `@Observable` 具体类，经 `.environment` 注入视图树。
- 两个装配点：`AppDependencies`（触发引擎/通知/路由/后台任务）、`AppEnvironment`（音频录放）。
- 服务全部先定义 protocol（`AudioRecording` / `CircleServicing` / `TriggerEngineProtocol` …），配套 `Fake*` 实现供测试；新增服务请沿用此模式。
- `AppDependencies.registerBackgroundTasks()` 必须在 App 启动完成前调用（BGTaskScheduler 限制）；UI/单元测试下 `bootstrap(requestPermissions: false)` 跳过系统权限弹窗（否则会卡死 XCUITest）。

### 核心状态机

`CapsuleState`：`buried → developing → developed → opened`，**只许前进不许回退**（`progressRank` 保证，见 D27）。显影推进由 `TriggerEngine` 判定三把锁后驱动。

已定产品决策：用户可自我选择重听自己的胶囊（含埋下后立即播）——「buried 不可直接播」是 WONTFIX，不要再当 bug 提。

## 约束与惯例

- **临床措辞禁令**（架构文档 §10）：产品定位「陪伴」，UI 文案 / agent 提示词 / Info.plist 隐私说明严禁临床/医疗词汇（治疗、诊断、症状、焦虑症等），`scripts/check-clinical-words.sh` 强制扫描。
- 文档即源头真相：架构设计在 `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md`，v1 路线图与各计划在 `docs/superpowers/plans/`。改动涉及架构决策时先对照这两处。
- DEBUG 专属 Dev 工具（设置 → Dev 工具：种示例数据、手动触发浮现等）须用编译条件包裹，Release 剥离。
- CloudKit 真同步、CKShare、HealthKit、真 agent 联调均需真机 + Apple Developer 账号，本地开发以模拟器 + Fake 服务为主。
