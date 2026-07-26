#if DEBUG
import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 屏幕巡检（仅 DEBUG）—— 启动参数直达任意一屏，配合 `scripts/tour-shots.sh`
/// 在无 XCUITest 的环境里做逐屏截图验收（#85 dark mode 之类的目视回归）。
///
/// 用法：`simctl launch <udid> com.voxlue.voxule -uiTourScreen shelf-grid`。
/// `-key value` 形式的启动参数会自动进 UserDefaults arguments 域，直接读即可。
/// 数据侧走内存容器 + DevSampleData 种子，音频/圈服务走 Fake —— 与 #Preview 同一套假件，
/// 不碰真麦克风、真 CloudKit，也不弹权限窗（权限窗会盖住截图）。
enum ScreenTour {

    /// 巡检可达的屏 —— rawValue 即启动参数取值。
    enum Target: String, CaseIterable {
        case home                               // 首页（含 tab bar 玻璃 chrome）
        case shelf                              // 样片墙 · List 形态
        case shelfGrid = "shelf-grid"           // 样片墙 · contact-sheet 形态（含首切提示横幅）
        case record                             // 冲洗台
        case framing                            // 装裱
        case detail                             // 胶囊详情（developed）
        case surfaced                           // 浮现卡（developing）
        case map                                // 地图
        case settings                           // 设置
        case cadence                            // 浮现频率
        case health                             // 陪伴授权
        case devtools                           // Dev 工具
        case circles                            // 声音圈列表
        case circleDetail = "circle-detail"     // 圈详情
        case createCircle = "create-circle"     // 新建圈
        case acceptInvite = "accept-invite"     // 接受邀请落地页
        case about                              // 关于
        case catalog                            // 设计图鉴（含暗房翻面对照段）
        case onboarding                         // 首启引导
    }

    /// 当前进程要巡检的屏；非巡检启动为 nil。
    static let target: Target? = UserDefaults.standard
        .string(forKey: "uiTourScreen")
        .flatMap(Target.init(rawValue:))

    /// 巡检用内存容器 —— 种入 DevSampleData 全量样本，并给第一个圈补两位成员
    /// （圈详情屏需要成员列表非空才验得到 dark 形态）。
    @MainActor
    static func makeSeededContainer() -> ModelContainer {
        let container = try! VoxlueModelContainer.make(inMemory: true)
        try? DevSampleData.seedAll(into: container.mainContext)
        let circles = (try? container.mainContext.fetch(FetchDescriptor<VoxlueData.Circle>())) ?? []
        if let first = circles.first {
            first.members = [
                CircleMember(name: "我", userRecordID: "me", role: .owner),
                CircleMember(name: "外婆", userRecordID: "grandma", role: .member),
            ]
            try? container.mainContext.save()
        }
        return container
    }

    /// 巡检前把几把 AppStorage 钥匙拧到目标屏需要的位置。
    /// 模拟器跨 run 残留是常态（同 XCUITest 的教训），必须显式设置而不是依赖默认值。
    static func primeDefaults(for target: Target) {
        let defaults = UserDefaults.standard
        // 引导 sheet 会盖住一切，一律跳过 —— onboarding 屏由宿主直接渲染，不走 sheet。
        defaults.set(true, forKey: "voxlue.hasSeenOnboarding")
        defaults.set(target == .shelfGrid ? "contactSheet" : "list", forKey: "shelf.layout")
        // contact-sheet 屏顺带验首切提示横幅的 dark 形态。
        defaults.set(false, forKey: "shelf.contactSheetHintSeen")
    }
}

/// 巡检宿主 —— 按 target 渲染对应屏。取代 RootTabView 挂在场景根部，
/// 环境注入由 voxuleApp 照常完成（容器/服务已在 init 阶段换成巡检假件）。
struct ScreenTourHost: View {
    let target: ScreenTour.Target

    @Environment(DeepLinkRouter.self) private var shareRouter
    @Environment(HealthEnv.self) private var healthEnv
    @Query private var capsules: [VoxlueData.Capsule]
    @Query private var circles: [VoxlueData.Circle]

    var body: some View {
        switch target {
        case .home:
            RootTabView()
        case .shelf, .shelfGrid:
            ShelfView()
        case .record:
            RecordView()
        case .framing:
            NavigationStack {
                FramingView(
                    recording: RecordingResult(
                        audioData: Data(),
                        duration: 12,
                        waveform: FakeAudioRecording.fakeWaveform
                    ),
                    intelligence: FakeIntelligenceServicing(title: "外婆喊吃饭")
                ) {}
            }
        case .detail:
            NavigationStack {
                if let capsule = capsules.first(where: { $0.state == .developed }) {
                    CapsuleDetailView(capsule: capsule)
                }
            }
        case .surfaced:
            NavigationStack {
                if let capsule = capsules.first(where: { $0.state == .developing }) {
                    SurfacedCapsuleView(capsuleID: capsule.id)
                }
            }
        case .map:
            NavigationStack { CapsuleMapView() }
        case .settings:
            NavigationStack { SettingsView() }
        case .cadence:
            NavigationStack { CadenceSettingsView() }
        case .health:
            NavigationStack { HealthAuthorizationView(health: healthEnv.provider) }
        case .devtools:
            NavigationStack { DevToolsView() }
        case .circles:
            CircleListView()
        case .circleDetail:
            NavigationStack {
                if let circle = circles.first {
                    CircleDetailView(circle: circle)
                }
            }
        case .createCircle:
            CreateCircleView()
        case .acceptInvite:
            // 驱动 app 级 sheet 走真实呈现路径 —— Fake 服务对 icloud.com/share 链接放行，
            // 落在「已加入」形态。
            PaperBackground()
                .ignoresSafeArea()
                .onAppear {
                    shareRouter.handleIncomingShare(
                        url: URL(string: "https://www.icloud.com/share/tour-fake")!
                    )
                }
        case .about:
            NavigationStack { AboutView() }
        case .catalog:
            NavigationStack { DesignCatalogView() }
        case .onboarding:
            OnboardingView()
        }
    }
}
#endif
