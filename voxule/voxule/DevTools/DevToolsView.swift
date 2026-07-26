#if DEBUG
import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// Dev 工具菜单 —— 仅 DEBUG 构建可见，挂在 `SettingsView` 底部。
/// 让前端不用录真音频、不用真后台 / 真账号，也能在样片墙 / 地图 / 我 / 浮现卡四处看到饱满内容。
struct DevToolsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppDependencies.self) private var dependencies

    @State private var lastAction: String?
    @State private var confirmingWipe = false

    /// 当前 ModelContainer 是否走 CloudKit 镜像 —— 由 `voxuleApp.init` 在选完
    /// 生产/降级容器时设。`ModelConfiguration.cloudKitDatabase` 非 Equatable，所以
    /// 这边不走运行时反射，而是从 App 壳层带过来。
    private var isCloudKitMirrored: Bool { voxuleApp.isCloudKitMirrored }

    var body: some View {
        Form {
            Section {
                Button {
                    do {
                        try DevSampleData.seedAll(into: context)
                        lastAction = "已种入 8 枚胶囊 + 2 个声音圈。"
                    } catch {
                        lastAction = "种入失败：\(error.localizedDescription)"
                    }
                } label: {
                    Label("种入示例数据", systemImage: "leaf")
                }

                Button {
                    confirmingWipe = true
                } label: {
                    Label("清空所有胶囊与圈", systemImage: "trash")
                        .foregroundStyle(isCloudKitMirrored ? Color.secondary : Color.red)
                }
                .disabled(isCloudKitMirrored)
            } header: {
                Text("种子数据")
            } footer: {
                if isCloudKitMirrored {
                    Text("示例胶囊覆盖三种锁、四种状态、两种 recipient；音频是程序生成的 1.6s 提示音，可以真回放。\n\n清空按钮在 CloudKit 镜像模式下禁用 —— 避免顺手把 iCloud 私有库的真胶囊也一并删掉。要清空请在非 iCloud 账号的模拟器上重装 App。")
                } else {
                    Text("示例胶囊覆盖三种锁、四种状态、两种 recipient；音频是程序生成的 1.6s 提示音，可以真回放。重复点击「种入」会累积，要重来请先「清空」。")
                }
            }

            Section {
                Button {
                    Task { await surfaceFirstBuried() }
                } label: {
                    Label("手动浮现一枚胶囊", systemImage: "wand.and.stars")
                }
            } header: {
                Text("触发引擎")
            } footer: {
                Text("挑第一枚 .buried 胶囊调用 TriggerEngine.surface()，跳过真 agent / 真后台。胶囊会进入 developing，下次深链进入即可看「浮现卡」。")
            }

            Section {
                Button {
                    CadenceSetting.current = .occasionally
                    // 与 CadenceSettingsView 保持一致 —— 改完立刻取消 / 重排 BGTask，
                    // 否则上次提交的请求会继续按旧 cadence 触发。
                    Task { await voxuleApp.scheduleNextSurfacing() }
                    lastAction = "cadence 已重置为「偶尔」，BGTask 重排。"
                } label: {
                    Label("重置 cadence 为「偶尔」", systemImage: "arrow.counterclockwise")
                }

                Button {
                    // 直接戳 UserDefaults —— Onboarding 那边用的就是这把 key，
                    // 不走 @AppStorage 绑定是为了省一个 @State 字段，纯 Dev 工具不必要。
                    UserDefaults.standard.set(false, forKey: "voxlue.hasSeenOnboarding")
                    lastAction = "已重置首启引导 —— 下次冷启动 App 会再弹一次"
                } label: {
                    Label("重新看一遍首启引导", systemImage: "sparkles")
                }
            } header: {
                Text("其他")
            }

            if let lastAction {
                Section {
                    Text(lastAction)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VoxlueColor.paper.ignoresSafeArea())
        .navigationTitle("Dev 工具")
        .alert("清空全部胶囊与圈？", isPresented: $confirmingWipe) {
            Button("清空", role: .destructive) {
                DevSampleData.wipe(context: context)
                // 路由可能指向已被删的 capsule —— 一起置空，避免 sheet 还试图弹一枚不存在的胶囊。
                dependencies.router.routedCapsuleID = nil
                lastAction = "已清空全部胶囊与圈。"
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("仅本设备本地库 —— CloudKit 镜像模式下本按钮已禁用，所以这里执行不到镜像数据。")
        }
    }

    /// 挑第一枚 .buried 胶囊调用 TriggerEngine.surface()。
    /// 区分「库里没胶囊」与「胶囊全都浮过了」两种情形，便于自查。
    private func surfaceFirstBuried() async {
        let descriptor = FetchDescriptor<VoxlueData.Capsule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let capsules = (try? context.fetch(descriptor)) ?? []
        guard let target = capsules.first(where: { $0.state == .buried }) else {
            lastAction = capsules.isEmpty
                ? "库里还没胶囊，先「种入示例数据」。"
                : "所有胶囊都已浮过 —— 先「清空」再「种入」可重置。"
            return
        }
        await dependencies.engine.surface(capsuleID: target.id)
        // 同时填好路由 routedCapsuleID 让浮现卡直接弹出。
        dependencies.router.routedCapsuleID = target.id
        lastAction = "已浮现「\(target.title.isEmpty ? "（无题）" : target.title)」。"
    }
}
#endif
