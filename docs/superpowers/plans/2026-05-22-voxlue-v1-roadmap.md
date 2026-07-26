# voxlue v1 实现路线图与分工总览

> 日期：2026-05-22 · 状态：**v1 核心六份计划全部完成并合入 `main`，整体回归通过**（见 §7）
> 配套设计文档：`docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md`
> 配套分计划：本目录 `2026-05-22-voxlue-02..06-*.md`（共 5 份）

---

## 0. 这份文档是什么

这是 voxlue v1 核心档的**总路线图**。它把架构文档 §11「v1 核心·必做」拆成 6 份可独立执行的实现计划，并钉死两件事：

1. **分工边界** —— 谁做哪部分，见 §2。
2. **接口契约** —— 两个人之间的协议层，见 §3。锁死契约后，前端与协作者可以**并行开工、各自跑测试**，互不阻塞。

读者有两类：
- **你（前端轨）** —— 负责全部 SwiftUI 界面、设计系统、App 壳层。
- **协作者（协作者轨）** —— 负责数据层、领域服务层、平台能力层、云端 agent 与后端代理。

计划 01（数据层）已完成并合入 `main`，本路线图从计划 02 起。

---

## 1. v1 计划地图

| 计划 | 标题 | 主要产出 | 主责轨 | 依赖 / 状态 |
|---|---|---|---|---|
| 01 | 项目骨架与数据层 | `VoxlueData` 包（4 个 @Model、容器、CapsuleStore） | 协作者 | —— · ✅ 已合入 |
| 02 | 录音→装裱→回放主循环 | `AudioEngine` 服务；埋下/装裱/回放/样片墙 UI | 双轨 | 01 · ✅ PR #2 |
| 03 | TriggerEngine 三把锁 | `TriggerEngine`+`GeofenceScheduler`+`NotificationService`；灵动岛与地图 UI | 双轨 | 01、02 · ✅ PR #3 |
| 04 | 设计系统与液态玻璃 | `VoxlueDesign` 包（tokens、暗房控件、玻璃导航、显影动效） | 前端 | 无 · ✅ PR #1 |
| 05 | 声音圈共享 | `CircleService`（CKShare）；声音圈 UI | 双轨 | 01、02 · ✅ PR #4 |
| 06 | 云端 agent 闭环 | `AgentGateway`+`SignalDistiller`+`IntelligenceService`；serverless 代理 | 双轨 | 01、02、03 · ✅ PR #5 |

### 依赖与并行图

```
            ┌─────────────────────────────────────────────┐
01 数据层 ✅ ─┤                                             │
            ├─▶ 02 录音主循环 ─┬─▶ 03 触发引擎 ─▶ 06 agent 闭环
            │                  └─▶ 05 声音圈              │
            └─────────────────────────────────────────────┘
04 设计系统 ── 无依赖，前端轨最先开工，贯穿 02/03/05/06 的所有 UI 任务
```

**关键并行点：** 计划 04（设计系统）不依赖任何后端，前端轨**第一件事就是做计划 04**。与此同时协作者轨开计划 02 的服务部分。两轨在计划 02 的 UI 任务处第一次汇合 —— 那时设计系统已就绪、服务已有假实现，UI 可顺畅落地。

---

## 2. 双轨分工

### 2.1 前端轨（你）

| 范围 | 内容 |
|---|---|
| 设计系统层 | `VoxlueDesign` 包全部 —— 计划 04 整份 |
| 功能模块层 | 全部 SwiftUI 视图：样片墙、地图、埋下流程、胶囊详情/回放、声音圈、我 —— 散落在计划 02/03/05/06 标 `【前端】` 的任务 |
| App 壳层 | App 入口、场景、深链/通知路由、依赖装配（DI 容器）—— 计划 02 起逐步搭，计划 03 完成路由 |

### 2.2 协作者轨

| 范围 | 内容 |
|---|---|
| 数据层 | `VoxlueData` —— 计划 01 ✅；后续计划按需扩 CapsuleStore 查询方法 |
| 领域服务层 | `VoxlueServices` 包：AudioEngine、TriggerEngine、CircleService、AgentGateway、SignalDistiller、IntelligenceService、NotificationService |
| 平台能力层 | 各平台能力的 wrapper（协议 + 真实现 + 假实现）：定位、音频会话、HealthKit、ActivityKit、远端模型客户端 |
| 后端 | agent 密钥中转 serverless 函数（v1 唯一自建服务端，无数据库） |

### 2.3 两轨如何不互相阻塞

契约优先（contract-first）：

1. **协作者每个服务先交「协议 + 假实现」再交真实现。** 计划里每个服务任务的第一步就是定义协议与一个 `Fake*` 假实现（返回固定假数据）。假实现一旦合入，前端就能 `import VoxlueServices`、用假实现驱动视图与 `#Preview`，不必等真实现。
2. **前端先交设计系统（计划 04）。** 所有 UI 任务依赖 `VoxlueDesign` 的控件与 tokens。
3. **SwiftData 模型已固定（计划 01）。** UI 读数据直接用 `@Query`，写数据走 `CapsuleStore`，两轨都依赖同一份已合入的 `VoxlueData`。

> 约定：标 `【协作者】` 的任务必须先于同计划里标 `【前端】` 的对应任务合入「协议 + 假实现」。真实现可晚于前端任务，只要不改协议签名。

---

## 3. 接口契约（前后端边界）

以下协议是两轨的**唯一耦合面**。协议放在 `VoxlueServices` 包；每个协议都配一个 `Fake*` 假实现（同包，供预览与 UI 测试）。**协议签名一经合入即冻结**，要改须双轨同意并同步更新本节。

服务以 `@Observable final class` 实现协议（MV 模式，无 ViewModel）。视图层注入时持有具体类型或 `@Observable` 包装以保留 SwiftUI 观察；各计划给出具体注入写法。`VoxlueData` 已有的 `CapsuleStore` 是具体类（非协议），读数据用 `@Query`。

### 3.0 包布局

`VoxlueKit` 是仓库唯一的本地 SPM 包，内含三个 library 目标，对应架构文档 §4 的三包划分：

| 目标 | 内容 | 落地计划 |
|---|---|---|
| `VoxlueData` | SwiftData 模型、容器、`CapsuleStore` | 01 ✅ |
| `VoxlueServices` | §3 全部服务协议、`Fake*` 假实现、真实现 | 02 新建，03/05/06 扩充 |
| `VoxlueDesign` | 设计 tokens、暗房控件、玻璃导航、显影动效 | 04 新建 |

依赖方向：`VoxlueServices` → `VoxlueData`；`VoxlueDesign` 独立、不依赖另两者；App target 接入全部三个。新增目标只改同一份 `VoxlueKit/Package.swift`，不另建包。

### 3.1 AudioEngine（计划 02）

```swift
/// 一次录音的产物。
public struct RecordingResult: Sendable, Equatable, Hashable {
    public let audioData: Data
    public let duration: TimeInterval
    public let waveform: [Float]   // 归一化 0...1，60–120 个采样点
}

/// 录音器。
@MainActor public protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var elapsed: TimeInterval { get }            // 录制中实时秒数，驱动 UI
    func requestPermission() async -> Bool
    func start() throws
    func stop() async throws -> RecordingResult
    func cancel()
}

/// 播放器。
@MainActor public protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var progress: Double { get }                 // 0...1
    func load(_ data: Data) throws
    func play()
    func pause()
    func seek(toProgress progress: Double)
}
```

实现：`AudioEngine`（真，AVFoundation）、`FakeAudioRecording` / `FakeAudioPlaying`（假，返回固定 8 秒假波形）。

### 3.2 TriggerEngine / NotificationService（计划 03）

```swift
/// 显影触发引擎 —— App 的心脏，纯后台、不依赖 UI。
@MainActor public protocol TriggerEngineProtocol: AnyObject {
    /// 让某枚胶囊进入 developing（被围栏/通知/agent 调用）。
    func surface(capsuleID: UUID) async
    /// App 启动/后台刷新时全量重扫过期时间锁与命中地点锁。
    func reconcile() async
    /// 当前正在显影中的胶囊（驱动灵动岛 UI）。
    var developingCapsuleIDs: [UUID] { get }
}

/// 本地通知调度（时间锁兜底）。
public protocol NotificationScheduling: Sendable {
    func requestPermission() async -> Bool
    func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws
    func cancel(capsuleID: UUID) async
}

/// 定位 wrapper（平台能力层）。
public protocol LocationProviding: Sendable {
    func requestPermission() async -> Bool
    /// 把这批围栏交给系统监听（内部已按「最近 20 个」裁剪）。
    func monitor(regions: [GeofenceRegion]) async
    var events: AsyncStream<GeofenceEvent> { get }   // 进入围栏事件流
}
public struct GeofenceRegion: Sendable, Hashable {
    public let capsuleID: UUID
    public let latitude, longitude, radius: Double
}
public enum GeofenceEvent: Sendable { case entered(capsuleID: UUID) }
```

`GeofenceScheduler` 是 `TriggerEngine` 内部组件（就近取 20 个围栏轮换），不对前端暴露。

### 3.3 CircleService（计划 05）

```swift
public struct ShareInvitation: Sendable {
    public let url: URL          // CKShare 链接，用于 iMessage/分享
}

@MainActor public protocol CircleServicing: AnyObject {
    func createCircle(name: String) async throws -> Circle
    /// 为圈生成共享邀请。
    func makeInvitation(for circle: Circle) async throws -> ShareInvitation
    /// 接受他人共享链接。
    func acceptShare(from url: URL) async throws
    func circles() async throws -> [Circle]
}
```

实现：`CircleService`（真，SwiftData 原生共享 / CKShare）、`FakeCircleServicing`（假）。

### 3.4 Agent 闭环（计划 06）

```swift
/// 端侧脱敏后越过网络边界的抽象摘要 —— 唯一出设备的健康相关数据。
public struct StateDigest: Sendable, Codable {
    public let tension: Level        // 紧绷度
    public let sleep: Level          // 睡眠质量
    public let calmCapsulesAvailable: Int
    public let daysSinceLastSurfacing: Int
    public enum Level: String, Sendable, Codable { case low, medium, high }
}

/// 端侧脱敏闸门：HealthKit 原始数据 → StateDigest。原始数据永不出设备。
public protocol SignalDistilling: Sendable {
    func distill() async -> StateDigest
}

/// 云端 agent 网关：构建请求、接收工具调用、派发、循环。
@MainActor public protocol AgentGatewaying: AnyObject {
    /// 跑一轮情绪浮现闭环；返回 agent 是否决定浮现及浮现哪枚。
    func runSurfacingCycle() async throws -> SurfacingDecision
}
public enum SurfacingDecision: Sendable { case surface(capsuleID: UUID), hold }

/// 端侧 Foundation Models（自动标题/标签、离线兜底）。
public protocol IntelligenceServicing: Sendable {
    func draftTitle(forTranscriptHint hint: String) async -> String?
}
```

`AgentGateway` 经 `RemoteModelClient` 调 serverless 代理；代理只转发、持有 API key、无数据库。

---

## 4. 排期与里程碑

建议排期（两轨并行）：

| 阶段 | 前端轨 | 协作者轨 |
|---|---|---|
| 第 1 周 | 计划 04 设计系统 | 计划 02 的 AudioEngine 协议+假实现+真实现 |
| 第 2 周 | 计划 02 的 UI（埋下/装裱/回放/样片墙） | 计划 03 的 TriggerEngine + 平台 wrapper |
| 第 3 周 | 计划 03 的 UI（灵动岛/地图）+ 壳层路由 | 计划 05 的 CircleService |
| 第 4 周 | 计划 05 的 UI（声音圈）+ 计划 06 的 UI 触点 | 计划 06 的 agent 闭环 + serverless 代理 |
| 第 5 周 | 联调、demo 打磨 | 联调、demo 打磨 |

**Demo 里程碑（v1 核心完成判据）：** 录一段声 → 选一把锁装裱埋下 → 锁条件满足 → 灵动岛显影提醒 → 打开回放；声音圈可建可邀请；情绪锁能由 agent 闭环浮现一次。对应架构文档 §11「v1 核心·必做」全绿。

---

## 5. 仓库与协作约定

- **分支：** 每份计划开一条 `plan-0N-<name>` 分支，计划内每个 Task 一个提交，完成后开 PR 合入 `main`。
- **提交信息：** 沿用计划 01 风格 —— `feat(audio): …` / `test(trigger): …`，中文 conventional commits。
- **认领：** 协作者认领计划 02/03/05/06 的 `【协作者】` 任务；你认领计划 04 整份及各计划 `【前端】` 任务。每个计划顶部的任务清单标了归属。
- **执行方式：** 每份计划文件头部标注了 superpowers 执行子技能；可用 `subagent-driven-development` 逐 Task 执行。
- **契约变更：** 任何要改 §3 协议签名的需求，先改本文件 §3 并知会对轨，再动代码。

---

## 6. 任务归属标记约定（各分计划内使用）

每份分计划的每个 Task 标题后带一个归属标记：

- `【协作者】` —— 协作者轨负责（服务、数据、平台、agent、后端）。
- `【前端】` —— 前端轨负责（你：视图、设计系统、壳层）。
- `【协作者→前端】` —— 交接点：协作者交付协议+假实现后，前端据此开工。

分计划清单：
- `2026-05-22-voxlue-02-recording-loop.md` —— 录音→装裱→回放主循环
- `2026-05-22-voxlue-03-trigger-engine.md` —— TriggerEngine 三把锁
- `2026-05-22-voxlue-04-design-system.md` —— 设计系统与液态玻璃
- `2026-05-22-voxlue-05-circle-sharing.md` —— 声音圈共享
- `2026-05-22-voxlue-06-agent-loop.md` —— 云端 agent 闭环

---

## 7. v1 执行结果与整体回归（2026-05-22）

六份计划已全部执行、过代码评审、落实修复并合入 `main`。本节记录落地结果与一次跨六份计划的整体回归。

### 7.1 计划落地

| 计划 | PR | 评审 / 返修要点 |
|---|---|---|
| 04 设计系统 | #1 | 评审通过，无返修。`VoxlueDesign` 包先行落地，供其余计划复用。 |
| 02 录放主循环 | #2 | 3 项 Critical：共享 `AudioEngine` 拆为录、放两个独立实例；计时器泄漏修复；错误统一走告警弹窗分流。 |
| 03 触发引擎 | #3 | 接通通知点击路由（新增 `NotificationDelegate`）；清理围栏裁剪死代码。 |
| 05 声音圈共享 | #4 | `DeepLinkRouter` 加防重入保护；`RecordingResult` 补 `Hashable`、`Identifiable` 归位。 |
| 06 云端 agent | #5 | 2 项 Critical：浮现 BGTask 从未提交 → `.task` 内补 `scheduleNextSurfacing()`；cadence 改动不重排 → 设置页改后即时取消并重排。另加 phase 校验、JSON 解析加固、请求超时、Worker `tsc` 加固。 |

### 7.2 整体回归结果

| 检查项 | 结果 |
|---|---|
| `swift test`（VoxlueKit 包，macOS） | ✅ 108 测试通过 |
| App 构建（`xcodebuild` iPhone 17 模拟器） | ✅ BUILD SUCCEEDED |
| `voxuleTests` | ✅ 通过 |
| `voxuleUITests` | ✅ 通过（含录音→装裱→回放主循环端到端） |
| 临床措辞合规扫描（`scripts/check-clinical-words.sh`） | ✅ 无命中 |
| Worker 类型检查（`backend/agent-proxy` `tsc`） | ✅ 通过 |
| App 启动冒烟 | ✅ 正常启动 |

### 7.3 执行期适配

各计划独立成文、各自假设了不同的 App 壳层；执行时 `voxuleApp.swift` 采取**逐计划合并**而非替换，依赖装配（`AppEnvironment` / `AppDependencies` / `ServiceContainer` / `AgentContainer`）按需新建，视图接入 `RootTabView` 各 Tab。Swift 6.2 严格并发与 iOS-only API 各处用 `#if os(iOS)` 守护以保 macOS `swift test` 可编译；`Capsule` / `Circle` 模型名与 SwiftUI 形状冲突处以 `VoxlueData.` 限定消歧。

### 7.4 仍需在开发者环境收尾

以下需真机 / 账号 / Xcode 工程操作，超出无头环境能力：

- **Widget Extension 目标**：`voxule/VoxlueWidget/` 源文件已就绪，须在 Xcode 新建 Widget Extension target 并加入这些文件。
- **真 CKShare 共享**：声音圈共享链路需真机 + iCloud 账号验证。
- **agent 代理部署**：`cd backend/agent-proxy && wrangler deploy`，部署后把真实 Worker 地址填入 `voxuleApp.agentProxyURL`。
- **三视图接导航**：cadence 设置 / HealthKit 授权 / 浮现卡三个视图已交付，待接入导航。
  → **2026-05-23 PR #6 完成**：CirclePickerView 接进装裱表单；cadence / HealthKit / 浮现卡三视图入导航；developing 态走 SurfacedCapsuleView 陪伴落地。
- **真 CKShare 共享**：声音圈共享链路需真机 + iCloud 账号验证。
- **agent 代理部署**：`cd backend/agent-proxy && wrangler deploy`，部署后把真实 Worker 地址填入 `voxuleApp.agentProxyURL`。
- **真 HealthKit / agent / CloudKit**：均需真机 + 对应账号与大模型 API key 才能端到端联调。

---

## 8. 设计语言全面落地（2026-05-23）

v1 主功能完成后，VoxlueDesign 包（P3 · Photographic Plate · 暗房黑白胶片美学，方案 B：玻璃只在 chrome，纸只在 content）首次接入应用屏。**13 个 view + 全局 tokens** 分两轮落地，覆盖 100% 用户可见界面。

### 8.1 第一轮 · hero 五屏（PR #8）

| 屏 | 形态 |
|---|---|
| 样片墙 ShelfView | 纸基底 + PhotoCard 网格（黑底声纹 + 朱章状态）+ GlassFloatingButton「冲一张」 |
| 装裱 FramingView | 纸基 Form，思源宋节标题，Space Mono 时长，朱红 CTA |
| 相片详情 CapsuleDetailView | 顶部 PhotoCard hero + 朱章；PaperCard 包回放与元数据 |
| 浮现卡 SurfacedCapsuleView | 中央 PaperCard + 朱红「听听看」 + 入场霜化开 FrostReveal |
| 冲洗台 RecordView | 暗房 negativeBlack 背景 + Crimson 大字时钟 + 朱红录音 / 停止 |

全局：voxuleApp 注册 4 套自定义字体（Crimson Pro · 思源宋 · Space Mono · Caveat），App 级 tint = `VoxlueColor.vermillion`。

### 8.2 第二轮 · 余下八屏（PR #10）

| 屏 | 形态 |
|---|---|
| 设置 / 浮现频率 / 陪伴授权 / Dev 工具 | 纸基 Form + 思源宋节标题 + 朱红 accent |
| 声音圈列表 + 详情 + 新建 + 接受邀请 | 纸基 + PaperCard rows + 朱红 CTA |
| 地图 CapsuleMapView | 玻璃 thinMaterial pin + 1pt 描边（埋下灰 / 显影中朱红） |

同 PR 清第一轮评审遗留：
- `VoxlueFontRegistrar.registerAll` 搬到 `static let _fontsRegistered`，进程级一次性
- `SealStamp` 收进 `PhotoCard` 作 `seal:` 可选参数，两处 overlay 重复消掉
- Picker / DatePicker `.tint` 统一沿用 App 级

### 8.3 累计 PR 与评审

| PR | 标题 | 评审要点 |
|---|---|---|
| #6 | 收尾视图接进导航 | M1/M2/M3/m3：抽 HealthEnv 不重复 CLLocationManager；SurfacedCapsuleView 听听看接通真回放；developing 三源注释；移除无观察 @Observable |
| #7 | DEBUG Dev 工具菜单 | C1：CloudKit 模式禁用清空；M1：重置 cadence 补排 BGTask |
| #8 | hero 五屏设计语言 | M1：frostReveal 用 DispatchQueue.main.async 延后翻 @State；m1：NavigationLink `.buttonStyle(.plain)` 隐 chevron；m4：录音页取消按钮改朱红 |
| #9 | 空状态居中（PR #8 回归） | 单行 fix：`.frame(maxWidth: .infinity, maxHeight: .infinity)` |
| #10 | 余下八屏设计语言 | B1：接受失败按钮恢复 `.bordered`；B2：地图 pin 改 `.thinMaterial` + 描边；S5：`CapsuleState.displayLabel` 扩展统一三处文案；S6：error 文案 ink + 朱红警告 icon |

### 8.4 留给 coworker 的部分（按用户分工）

- **`wrangler deploy`** serverless 代理并填真实 Worker URL 到 `voxuleApp.agentProxyURL`
- **真机** HealthKit / CKShare / 真 agent 联调
- **真 API key** 与大模型对接
- Xcode 新建 **Widget Extension target**（源文件已在 `voxule/VoxlueWidget/`，灵动岛 DevelopingIslandLabel 等待接入）

---

## 9. 多 agent 并行增量 PR 总账（2026-05-23 ~ 2026-05-24）

设计语言落地（§8）后的扫尾期，启用 worktree 隔离的并行 agent 工作流：主 agent 拆任务、分派 3 agent 并行写 / 评审 / 修 / 合主。截至本次更新已完成 12 批，**40+ 个独立 PR**。

### 9.1 按主题归纳

| 主题 | 涉及 PR |
|---|---|
| **导航 / IA 结构** | #14 主页改巨大录音键；#13 mic 居中；#20 样片墙 tab badge；#22 时间分段；#34 搜索 |
| **首页深化** | #16 长按录音 + 最近预览；#28 浮现待听 pill；#31 状态统计；#40 每日 prompt；#54 prompt 点击换一句 |
| **录音 / 装裱** | #15 装裱朱章预览；#21 「埋下」盖章仪式；#24 30s 软提示；#38 取消确认 |
| **详情 / 回放** | #17 播放呼吸（phaseAnimator）；#27 分享 + 划掉；#36 批注编辑；#41 显影 timeline；#48 改个名；#52 改个圈 |
| **声音圈** | #32 圈头部 PaperCard；#39 最近活动；#44 圈内胶囊改 CapsuleRow；#43 接受邀请风格化；#47 建圈字符上限；#51 邀请分享 sheet |
| **地图** | #19 pin 点开纸卡气泡；#45 「我的位置」+ PaperCard 空状态 |
| **浮现卡** | #29 「等等再说」；#50 「再听一次」 |
| **设置 / 关于 / Dev** | #18 「关于 voxlue」+ 哲学落地；#26 接 DesignCatalog；#33 重看引导；#30 Dev 重置引导；#49 「项目」section |
| **入场体验** | #25 首启 3 页引导；#46 陪伴授权页装饰 |
| **设计组件深化** | #23 朱章 kind 切换 transition + spring；#37 shelf swipeActions；#53 shelf row swipeActions |
| **对齐审计** | #35 三处偏移修；#42 五处 MarginNote 居中场景退出 |

### 9.2 多 agent 并行工作流要点

- 每个 agent 用 `isolation: worktree`，独立 derived-data path（`/tmp/voxule-dd-*`），互不冲突
- 文件作用域严格切分（同一批 3 个 PR 必须触不同文件）
- 主 agent 集中评审 + 合主 + 跑回归（`swift test` + `testRecordBuryPlayMainLoop` + clinical scan）
- 单一 PR 失败不阻塞同批其他 PR

### 9.3 两个 standalone 大坑（2026-05-24 ~ 2026-05-25 落地）

§9.1 扫尾期留下的两个 surface 太大、文件冲突太多的项目，分两个独立分支推进。

| 项目 | PR | 落地要点 |
|---|---|---|
| **暗房模式 dark theme** | #75 | 把 VoxlueDesign 六只 token（paper / paperHighlight / paperShadow / ink / graphite / darkroomGray）升级成 `Color.voxlueAdaptive(light:dark:)`；新增 6 个 `*Light` 固定原值 alias 给「永远在暗底之上」的语境（NegativeCard 文字、FilmPerforations、RecordView 整屏、PhotoCard waveform、DevelopingIslandLabel、CapsuleRow / CapsuleDetailView waveform）；vermillion / negativeBlack 不参与翻面。PaperGrain 缓存 key 加 isDark、改 NSCache 防内存堆增。DesignCatalog 加「翻面对照 + 整屏暗房样片」段。`GlassTint.cream` 也改 adaptive 避免 dark 下与背板同色失去玻璃感。13 屏 + 全局 tokens 一次性覆盖。评审反馈 3 Major（adaptivePalette / dark 端测试 / cream tint） + 1 Minor 全修。 |
| **contact-sheet 2 列网格** | #76 | 样片墙 ShelfView 加 `ShelfLayout` 枚举（list / contactSheet）+ `@AppStorage("shelf.layout")`，toolbar Menu/Picker 切换；新增 `contactSheetGrid`（ScrollView + LazyVStack 段头 + LazyVGrid 2 列），bucketGroups 按 bucket 收成连续段落；List 路径保留为默认（XCUI `testRecordBuryPlayMainLoop` cells.count 契约不破）。capsuleContextMenu helper 让列表与 grid 共享 ShareLink + 划掉行为。评审反馈 1 Critical（XCUI 残留 AppStorage —— voxuleApp init 显式重置）+ 1 Major（ForEach id 改 `\.bucket`）+ 几条 minor 全修。 |

至此 v1 路线图（§4–§9.3）全部交付，main 上 76 个 PR 合入。

---

## 10. v1.1 收尾批（2026-05-25）

PR #75 / #76 评审中记为「下次再说」的 minor / nit 在 §9.3 收尾后开 v1.1 批次一次性清掉（PR #77）。

| # | 来源 | 改动 |
|---|---|---|
| ① | #75 m2 | `HomeView.recentPreview` frame 168 → 180，留 lineLimit(2) 长 meta 与 seal 阴影余量；alignment 保持 .top 以与 scaleEffect anchor 协同 |
| ② | #75 n1 | `voxlueGlass` DRY —— 便捷重载内部转发给泛型版 `voxlueGlass(in:)`，单一实现源；corner 保持 `.circular` 默认避免悄改成 `.continuous` squircle |
| ③ | #75 n3 | `VoxlueColor.inkOnDark` 语义别名（== paperLight）；NegativeCard 标题示范迁移；ColorTests 加 `inkOnDarkIsAliasForPaperLight` 防漂移 |
| ④ | #76 m6 | contact-sheet 首切显示 `MarginNote「长按一张可分享或划掉」+ 朱红「知道了」`，`@AppStorage("shelf.contactSheetHintSeen")` 关一次永久 |
| ⑤ | #76 m7 | `PhotoCard` / `NegativeCard` meta `lineLimit 1 → 2`，半宽 grid 下长地名不再截 |

回归：swift test 114 通过（+1 别名断言）、`scripts/run-sim.sh --build-only` BUILD SUCCEEDED、临床措辞扫描无命中。

**配套基建（同期）**：`scripts/run-sim.sh` 一键构建+装+启 iPhone 17 模拟器（内置 `CODE_SIGNING_ALLOWED=NO` 绕本机 SwiftPM 资源 bundle codesign 预存在问题）；README 同步指向脚本。

---

## 11. v1.x 下期任务地图

v1 路线图（§4–§10）已完整交付。下期任务按两轨梳理 —— **前端轨** = 用户负责，**协作者轨** = 协作者负责。

### 11.1 前端轨候选（v1.2 / v1.3）

按价值优先级（高优先级两项已落 GitHub Issues）：

| 优先级 | 项目 | Issue / 触发 | 状态 |
|---|---|---|---|
| 高 | **真机 / 模拟器 13 屏 dark mode 目视验收** | #85 | ✅ v1.2（§12）模拟器侧完成，issue 已关 |
| 高 | **contact-sheet a11y 加固** | #86 | ✅ 代码侧 PR #91；VoiceOver 实听留真机 |
| 中 | **PhotoCard / CapsuleRow Preview 扩样** | 加长 meta / 长 title 变体让 lineLimit(2) 数学回归靠 Preview 抓 | ✅ PR #93 |
| 中 | **微动画 polish** | ShelfView 滚动惯性、PhotoCard 按下手感、bucket header 出现 `.transition` | ✅ PR #93 |
| 低 | **用户头像 emoji 池扩展** | `CircleEmojiHash` 当前 hash 池较窄 | ✅ PR #92（连稳定性一起修） |
| 低 | **iPad 适配 spike** | contact-sheet 应 3 列；split detail；v2 前先做 spike | 未启动 |

### 11.2 协作者轨剩余项（v1 末延期、待协作者推进）

这些项在 §7.4 / §8.4 已登记，**无头环境搞不定**、需真机 + 账号 + 部署。已全部落 GitHub Issues（label `coworker-track`）：

| 项目 | Issue | 阻塞条件 |
|---|---|---|
| **VoxlueWidget Extension target** | #78 | Xcode 新建 Widget Extension target、加入 `voxule/VoxlueWidget/` 源文件、跑通灵动岛 LiveActivity |
| **agent-proxy Cloudflare Worker 部署** | #79 | `wrangler login` + secrets 配 LLM API key + `wrangler deploy`，URL 填回 `voxuleApp.agentProxyURL` |
| **真 CKShare 共享链路联调** | #80 | 真机 + iCloud 账号 |
| **真 HealthKit 授权 + 数据流** | #81 | 真机 + HealthKit 授权弹窗 + 真数据 |
| **真 agent 调用 + 大模型 API key** | #82 | 依赖 #79；真机 + Cloudflare Worker secrets |
| **真 CloudKit 同步** | #83 | CloudKit Dashboard 建 container + Apple Developer 账号 + 带 iCloud 能力的 Team |
| **RecordView / CapsuleDetailView dark toolbar 真机验收** | #84 | 真机 dark 目视一遍 |

### 11.3 v2 候选方向（未启动 spike）

只是方向标记，不进入排期 —— 待 v1.x 落定后再 brainstorm：

- 多人协同：声音圈成员实时听同一段、看见对方在听
- 多段拼接 / 章节锁 —— 一枚胶囊承载一序列声音片段
- 浮现智能化：基于 HealthKit 长期模式（睡眠/活动节律）的 agent 决策
- 跨胶囊相关性：相同地点 / 情绪锁的浮现联动
- 桌面端 / iPad / Vision 适配

### 11.4 接下来的 PR 节奏建议

- **§11.1 高优先级两项已开 issues** —— #85 dark 真机验收、#86 contact-sheet a11y。两者可作 v1.2 双 PR 批，互不冲突文件可并行。
- **§11.2 协作者轨 7 项全部进 GitHub Issues** —— #78–#84，带 `coworker-track` label，便于协作者认领与追踪。
- **v2 方向**等用户主动提需求时再走 brainstorming skill 展开。

GitHub Labels：`frontend-track`（绿）= 用户负责、`coworker-track`（红）= 协作者负责。

---

## 12. v1.2 前端批交付记录（2026-07-26）

§11.1 前端轨除 iPad spike 外全部交付，三个 PR：

| PR | 内容 |
|---|---|
| #91 | contact-sheet a11y 加固（#86 代码侧）：提示横幅 `.combine`+`.isHeader`+hint+默认 `accessibilityAction`；grid `.contain` region「样片小样张」 |
| #92 | #85 dark 巡检落地：**ScreenTour 截图基建**（DEBUG `-uiTourScreen` 直达 19 屏 + `scripts/tour-shots.sh` simctl 逐屏截图）；巡检修复四处 —— 浮现卡批注重叠、圈列表双 chevron、详情页空音频进页弹 alert 改 inline 批注、About 八色 swatch 改 `adaptivePalette`；`CircleEmoji` FNV-1a 稳定映射（`String.hashValue` 每进程加种，同名稳定从未成立）+ 池扩展 + 固定向量测试；DevSampleData 音频改程序生成 1.6s WAV 可真回放 |
| #93 | Preview 长字段扩样（PhotoCard/NegativeCard/CapsuleRow 全宽+半宽变体）；微动画（`.pressableCard` 按下手感、contact-sheet 段落进场 transition 与 `.scrollTransition` 滚动惯性） |

**验收方式沉淀**：本环境跑不了 XCUITest，目视验收固化为 `scripts/run-sim.sh --build-only && scripts/tour-shots.sh [--appearance light]`，产物 `design/tour-shots/`（gitignore）。dark 19 屏 + light 抽查 6 屏逐张复核通过；#85 已关，#86 留 VoiceOver 真机实听一条。

**剩余开放**：前端轨仅 iPad spike（低优先级、v2 前置）；协作者轨 #78–#84 全部保持开放（需真机/账号/部署）。
