import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 声音圈列表 —— 自建的与受邀加入的圈都在这里。
struct CircleListView: View {
    @Environment(ServiceContainer.self) private var services

    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var allCapsules: [VoxlueData.Capsule]

    @State private var circles: [VoxlueData.Circle] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var loadError: String?
    /// 导航路径 —— 建圈成功后 append 新圈 id，自动推进其详情页（C8）。
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                PaperBackground().ignoresSafeArea()

                Group {
                    if isLoading {
                        loadingState
                    } else if let loadError {
                        errorState(loadError)
                    } else if circles.isEmpty {
                        emptyState
                    } else {
                        circlesList
                    }
                }
            }
            .navigationTitle("声音圈")
            .navigationDestination(for: UUID.self) { circleID in
                if let circle = circles.first(where: { $0.id == circleID }) {
                    CircleDetailView(circle: circle)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(VoxlueColor.ink)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(VoxlueColor.vermillion)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                // 建圈成功：先刷新列表（让 navigationDestination 能查到新圈），再推进其详情页（C8）。
                CreateCircleView(onCreated: { created in
                    Task {
                        await reload()
                        path.append(created.id)
                    }
                })
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private var loadingState: some View {
        VStack(spacing: VoxlueSpacing.md) {
            ProgressView()
                .tint(VoxlueColor.vermillion)
            Text("正在取声音圈…")
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: VoxlueSpacing.md) {
            // §4.11 实现卡：error 走「红 icloud icon」—— darkroomGray 太消极，
            // 朱红 icon 让用户一眼识别这是 iCloud 通信问题，不是空状态。
            // 文字仍走 ink + graphite，icon 是唯一的色温热点。
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 44))
                .foregroundStyle(VoxlueColor.vermillion)
            Text("声音圈没取到")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
            Text(message)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        // 不再复用样片墙的 Crimson display "voxlue" hero —— Crimson 给唯一显著时刻；
        // 这里走 SF symbol + 思源宋 + Caveat 描述，与样片墙保持对话感的差异。
        VStack(spacing: VoxlueSpacing.lg) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 44))
                .foregroundStyle(VoxlueColor.darkroomGray)
            Text("还没有声音圈")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
            // 居中 VStack 里不用 MarginNote 的左侧朱红短画 —— 会把视觉重心拽偏。
            Text("圈起来，几个人就够。")
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
                .multilineTextAlignment(.center)
            Button("建一个声音圈") { showCreateSheet = true }
                .font(VoxlueTypography.serifBody)
                .buttonStyle(.borderedProminent)
                .tint(VoxlueColor.vermillion)
                .padding(.top, VoxlueSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 圈列表 —— List 套 PaperCard 风格的 row。
    private var circlesList: some View {
        List(circles) { circle in
            NavigationLink(value: circle.id) {
                CircleRow(
                    circle: circle,
                    latestCapsuleTitle: latestTitle(forCircle: circle.id),
                    emoji: CircleEmoji.circleEmoji(forName: circle.name)
                )
            }
            // 与样片墙行同一手感 —— 按下轻沉，松手回弹（§11.1 微动画）。
            .buttonStyle(.pressableCard)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: VoxlueSpacing.sm,
                leading: VoxlueSpacing.lg,
                bottom: VoxlueSpacing.sm,
                trailing: VoxlueSpacing.lg
            ))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// 取该圈最新一颗胶囊的标题；无胶囊返回 nil，让行内不渲染那行。
    /// allCapsules 已按 createdAt 倒序，first(where:) 即最新。
    private func latestTitle(forCircle circleID: UUID) -> String? {
        guard let capsule = allCapsules.first(where: { $0.circleID == circleID }) else {
            return nil
        }
        let trimmed = capsule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "（无题）" : trimmed
    }

    private func reload() async {
        isLoading = true
        loadError = nil
        do {
            circles = try await services.circleService.circles()
        } catch {
            loadError = "iCloud 暂时连不上。"
        }
        isLoading = false
    }
}

/// 列表里的一行圈 —— 纸卡风。
private struct CircleRow: View {
    let circle: VoxlueData.Circle
    let latestCapsuleTitle: String?
    /// 由父级按圈名 hash 算好传进来 —— Row 不负责选 emoji，免得 Preview/测试时拿不到同一稳定值。
    let emoji: String

    private var memberCount: Int { circle.members?.count ?? 0 }

    var body: some View {
        PaperCard {
            HStack(spacing: VoxlueSpacing.md) {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(VoxlueColor.paperShadow.opacity(0.4), in: Circle())
                VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
                    Text(circle.name.isEmpty ? "（未命名的圈）" : circle.name)
                        .font(VoxlueTypography.serifTitle)
                        .foregroundStyle(VoxlueColor.ink)
                    Text("\(memberCount) 位成员")
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(VoxlueColor.graphite)
                    if let title = latestCapsuleTitle {
                        Text("最近一段：\(title)")
                            .font(VoxlueTypography.meta)
                            .foregroundStyle(VoxlueColor.graphite)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // 不自绘 chevron —— List 的 NavigationLink 自带系统 disclosure，
                // 再画一枚会双箭头（#85 dark 巡检发现）。样片墙行同此形态。
            }
        }
    }
}

#Preview("有圈") {
    CircleListView()
        .environment(ServiceContainer.preview())
        .environment(HealthEnv(provider: FakeHealthProviding(snapshot: nil)))
}

#Preview("空") {
    CircleListView()
        .environment(ServiceContainer.previewEmpty())
        .environment(HealthEnv(provider: FakeHealthProviding(snapshot: nil)))
}
