import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 样片墙 —— 全部胶囊按埋下时间倒序排开，存储与浏览中心。
/// 录音入口已搬到首页（HomeView）巨型 mic 键，这里不再放浮动入口，避免重复 chrome。
/// 第五轮：墙面按时间分段 —— 本周 / 上个月 / 更早，像档案箱的隔板。
/// 第六轮（§9.3）：加 contact-sheet 2 列网格作为可选布局，模仿摄影师小样张，
/// 同段时间的片子横向铺开。toolbar 切换 —— 默认列表保 XCUI 测试契约。
struct ShelfView: View {
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    /// SwiftData 上下文 —— contextMenu 的"划掉"走 context.delete + save。
    /// 这里不引 CapsuleStore，避免给样片墙再背一份依赖；
    /// 行级删除是纯本地操作，直接走 modelContext 已够。
    @Environment(\.modelContext) private var context

    /// 共享触发引擎 —— 划掉后取消通知 + 重排围栏（D10）。预览未注入时为 nil。
    @Environment(AppDependencies.self) private var dependencies: AppDependencies?

    /// 搜索词 —— 空串等价于不过滤，保留与 @Query 完全相同的渲染序，
    /// 保证 UI 测试 testRecordBuryPlayMainLoop 在默认空查询下不动行为契约。
    @State private var query = ""

    /// 二次确认的目标胶囊 —— 非 nil 即弹 alert，alert 关闭时复位为 nil。
    /// 用 Capsule? 而不是 Bool + 旁置 selected：
    /// .alert(_:isPresented:presenting:) 需要个非空值给 actions/message 闭包，
    /// 拿它当 identity 一并解决"弹谁"的歧义。
    @State private var confirmingDelete: VoxlueData.Capsule?

    /// 样片墙布局 —— list（默认、单列 PhotoCard）/ contactSheet（2 列网格小样张）。
    /// 用 rawValue String 进 AppStorage，跨进程会话保留用户的偏好；默认 .list
    /// 保 XCUI 测试 testRecordBuryPlayMainLoop 的 `cells.count == capsules.count` 契约。
    /// （voxuleApp init 在测试环境还会显式重置 "shelf.layout" 为 "list"，避免模拟器
    /// 残留 contactSheet 偏好破坏契约。）
    @AppStorage("shelf.layout") private var layoutRaw: String = ShelfLayout.list.rawValue

    /// 首次切到 contact-sheet 形态时一次性提示长按手势 —— grid 里没有 List 的
    /// 右滑入口，靠 contextMenu 兜底；iOS 用户习惯先试右滑，给个一次性 MarginNote
    /// 提醒「长按可分享或划掉」。看完关一次即永久消失，不再骚扰。
    @AppStorage("shelf.contactSheetHintSeen") private var contactSheetHintSeen: Bool = false

    private var layout: ShelfLayout {
        ShelfLayout(rawValue: layoutRaw) ?? .list
    }

    /// 时间分段 —— 顺序即渲染顺序，新鲜的在上。
    private enum Bucket: CaseIterable {
        case thisWeek   // 0–7 天
        case lastMonth  // 8–30 天
        case earlier    // 30+ 天

        var label: String {
            switch self {
            case .thisWeek:  "本周"
            case .lastMonth: "上个月"
            case .earlier:   "更早"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground().ignoresSafeArea()

                if capsules.isEmpty {
                    // 数据库本身为空 —— 首次到访，引去首页冲一张。
                    emptyState
                } else if filteredCapsules.isEmpty && !query.isEmpty {
                    // 数据库有片，但搜不到 —— 区别于空数据库的诗意空状态，
                    // 用一行 MarginNote 提示，避免覆盖整个区域的大字 display。
                    noMatchState
                } else {
                    switch layout {
                    case .list:         photoStack
                    case .contactSheet: contactSheetGrid
                    }
                }
            }
            .navigationTitle("样片墙")
            .searchable(text: $query, prompt: Text("找一段声音"))
            .toolbar {
                // 布局切换 —— 列表 / contact-sheet。藏进 Menu 里，
                // 避免在 chrome 上常露一个 segmented control 抢内容焦点。
                // 只当 capsules 非空时显示：墙是空的，给个布局开关没意义、还会绕过空态版面。
                ToolbarItem(placement: .topBarTrailing) {
                    if !capsules.isEmpty {
                        layoutMenu
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let capsule = capsules.first(where: { $0.id == id }) {
                    CapsuleDetailView(capsule: capsule)
                }
            }
            // 行级 contextMenu 的二次确认 —— 用 presenting: 把目标胶囊带进闭包。
            // isPresented 的 Binding 用 confirmingDelete != nil 推导：
            // alert 系统在 dismiss 时会回写 false，借此把 state 复位为 nil。
            .alert(
                "划掉这枚胶囊？",
                isPresented: Binding(
                    get: { confirmingDelete != nil },
                    set: { if !$0 { confirmingDelete = nil } }
                ),
                presenting: confirmingDelete
            ) { capsule in
                Button("划掉", role: .destructive) {
                    let id = capsule.id
                    context.delete(capsule)
                    try? context.save()
                    // 划掉后取消该胶囊待发通知、结束 Live Activity，并按剩余胶囊重排围栏（D10）。
                    Task { await dependencies?.engine.discard(capsuleID: id) }
                }
                Button("不了", role: .cancel) {}
            } message: { _ in
                Text("声音会从样片墙、地图和声音圈里消失。")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: VoxlueSpacing.lg) {
            // 大字 Crimson 斜体 display —— 给空状态一点旧派的留白与诗意。
            Text("voxlue")
                .font(VoxlueTypography.display)
                .foregroundStyle(VoxlueColor.darkroomGray)
            Text("样片墙还空着")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
            // 居中 VStack 里不用 MarginNote 的左侧朱红短画 —— 会把视觉重心拽偏。
            Text("去首页冲一张声音。")
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 搜不到匹配 —— 小份量提示，留给搜索栏继续输入的余地。
    /// 不复用 emptyState 的大字 display，那是给"墙真的空"的场合的。
    private var noMatchState: some View {
        VStack(spacing: VoxlueSpacing.sm) {
            Text("找不到匹配的声音")
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.ink)
            Text("换个词试试。")
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 应用搜索词过滤 —— 空串直通，匹配 title 或 placeName（若存在）。
    /// 在 shelfRows 之前过滤，bucket 划分才会跟着结果一起收敛。
    private var filteredCapsules: [VoxlueData.Capsule] {
        guard !query.isEmpty else { return capsules }
        return capsules.filter { capsule in
            if capsule.title.localizedCaseInsensitiveContains(query) {
                return true
            }
            if let place = capsule.placeName,
               place.localizedCaseInsensitiveContains(query) {
                return true
            }
            return false
        }
    }

    /// 把每个 capsule 标上所属 bucket，并打 firstInBucket 旗标。
    /// 摊平成一维数组 —— 这样 List 里只有一个 ForEach，cells.count == capsules.count，
    /// 不破 UI 测试契约。bucket header 直接挂在每段第一行的内容顶部，看上去仍是分段。
    private struct ShelfRow: Identifiable {
        let capsule: VoxlueData.Capsule
        let bucket: Bucket
        let firstInBucket: Bool
        var id: UUID { capsule.id }
    }

    private var shelfRows: [ShelfRow] {
        let now = Date()
        let calendar = Calendar.current

        func bucket(for date: Date) -> Bucket {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days <= 7  { return .thisWeek }
            if days <= 30 { return .lastMonth }
            return .earlier
        }

        // @Query 已按 createdAt desc 排好；filter 保留顺序，
        // 这里只需顺扫一遍，在 bucket 变化的边界标 firstInBucket = true。
        let source = filteredCapsules
        var rows: [ShelfRow] = []
        rows.reserveCapacity(source.count)
        var previousBucket: Bucket?
        for capsule in source {
            let b = bucket(for: capsule.createdAt)
            rows.append(ShelfRow(
                capsule: capsule,
                bucket: b,
                firstInBucket: b != previousBucket
            ))
            previousBucket = b
        }
        return rows
    }

    private var photoStack: some View {
        // 用 List 而不是 ScrollView+LazyVStack —— XCUI 通过 cells 语义遍历样片墙，
        // 切到 LazyVStack 会让 cells.count 为 0，破坏既有 UI 测试契约。
        // List 套上 plain 样式 + 透明背景 + 隐藏分隔线 + 透明 row background，
        // 视觉等同于 PhotoCard 网格。
        //
        // 为什么不用 Section / header：plain List 的 section header 会在 XCUITest 里
        // 算作一个独立 cell，破坏 cells.count == capsules.count 契约。
        // 折中方案：把 bucket 标签挂在该段第一行的内容顶部，行还是一行，cell 还是一个。
        List {
            ForEach(shelfRows) { row in
                NavigationLink(value: row.capsule.id) {
                    VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                        if row.firstInBucket {
                            sectionHeader(row.bucket.label)
                        }
                        CapsuleRow(capsule: row.capsule)
                    }
                }
                // pressableCard：移除系统默认高亮（同 .plain），并给按下一个
                // 轻微下沉手感 —— 相纸被指尖按住的实感（§11.1 微动画）。
                .buttonStyle(.pressableCard)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: VoxlueSpacing.sm,
                    leading: VoxlueSpacing.lg,
                    bottom: VoxlueSpacing.sm,
                    trailing: VoxlueSpacing.lg
                ))
                // 长按行 —— 不进详情就能分享 / 划掉。共享 helper，与 contact-sheet 一致。
                // 分享只在确有音频数据时露出，避免给 buried/空音频行甩个空按钮；
                // 划掉走 confirmingDelete = capsule，弹层在 NavigationStack 层级统一处理。
                .contextMenu { capsuleContextMenu(row.capsule) }
                // 右滑快捷入口 —— 长按只是发现路径之一，多数 iOS 用户先试右滑。
                // 与 contextMenu 并存：两条路通向同一组动作，谁先发现都行。
                // allowsFullSwipe: false —— 划掉是破坏性操作，不让一滑到底无确认就走。
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        confirmingDelete = row.capsule
                    } label: {
                        Label("划掉", systemImage: "trash")
                    }
                    .tint(VoxlueColor.vermillion)

                    if let data = row.capsule.audioData, !data.isEmpty {
                        ShareLink(
                            item: data,
                            preview: SharePreview(
                                row.capsule.title.isEmpty ? "（无题）" : row.capsule.title
                            )
                        ) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .tint(VoxlueColor.graphite)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// 区段引线 —— 朱红短画 + 石墨小字，像档案柜抽屉上贴的标签。
    /// 与 MarginNote 同款引线，但不用手写体 —— 这里是分隔，不是批注。
    /// 没有 .listRowInsets / .listRowBackground：这里不是独立 List row，
    /// 而是被嵌进该段首行 NavigationLink 内容顶部的一个 HStack。
    /// 左 padding 与 PhotoCard / NegativeCard 内部标题对齐（外 lg + 卡内 lg = 2lg），
    /// 否则短画悬在卡片标题左侧 12pt 空中，视觉上歪一寸。
    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: VoxlueSpacing.sm) {
            Rectangle()
                .fill(VoxlueColor.vermillion)
                .frame(width: 14, height: 1.5)
            Text(label)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
        .textCase(nil)
        .padding(.leading, VoxlueSpacing.lg)
        .padding(.top, VoxlueSpacing.sm)
        .padding(.bottom, VoxlueSpacing.xs)
    }

    // MARK: contact-sheet 2 列网格（§9.3）

    /// 按 bucket 把 shelfRows 收成连续段落 —— 同 bucket 的胶囊聚到一起，
    /// 整段一个 header + 一张 LazyVGrid，避免单元格穿越分段边界。
    /// 因 shelfRows 已按时间倒序、bucket 与时间单调对齐，扫一遍即可，无需排序。
    private var bucketGroups: [(bucket: Bucket, capsules: [VoxlueData.Capsule])] {
        var groups: [(bucket: Bucket, capsules: [VoxlueData.Capsule])] = []
        for row in shelfRows {
            if let last = groups.last, last.bucket == row.bucket {
                groups[groups.count - 1].capsules.append(row.capsule)
            } else {
                groups.append((bucket: row.bucket, capsules: [row.capsule]))
            }
        }
        return groups
    }

    /// 2 列 contact-sheet —— 摄影师的小样张，同段时间一张张铺开。
    /// 与 photoStack 共享 NavigationLink + contextMenu + swipeActions 语义；
    /// 但走 ScrollView+LazyVGrid 而不是 List：List 在 grid 形态下不存在，contact-sheet
    /// 也不复用 XCUI cells 契约（XCUI 测试默认走 .list 布局）。
    private var contactSheetGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: VoxlueSpacing.xl) {
                if !contactSheetHintSeen {
                    contactSheetHintBanner
                        .padding(.horizontal, VoxlueSpacing.lg)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                // bucket 三段互不重复，Bucket 自身是稳定 identity；
                // 用 \.offset 会让插入新片时第一段被整体 invalidate（diff 错位），
                // grid 内所有 NavigationLink 被迫 rebuild、SealStamp 入场动画再跑一遍。
                ForEach(bucketGroups, id: \.bucket) { group in
                    bucketSection(group)
                }
            }
            .padding(.vertical, VoxlueSpacing.lg)
            // 搜索词收敛 bucket 分组时，段落淡入 + 自顶轻移进场，
            // 而不是硬切（§11.1 微动画：bucket header 出现 .transition）。
            .animation(.easeOut(duration: 0.25), value: query)
        }
        // region 标识 —— .contain 让整张小样张成为 VoiceOver rotor「容器」里
        // 可跳转的一站，label 给这一站起名（#86）。
        .accessibilityElement(children: .contain)
        .accessibilityLabel("样片小样张")
    }

    /// contact-sheet 的一段 bucket —— 段头 + 2 列网格。
    private func bucketSection(
        _ group: (bucket: Bucket, capsules: [VoxlueData.Capsule])
    ) -> some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            // contact-sheet 段头已挂在外层 lg padding 容器里，无需再额外缩进。
            sectionHeader(group.bucket.label)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: VoxlueSpacing.md),
                    GridItem(.flexible(), spacing: VoxlueSpacing.md),
                ],
                spacing: VoxlueSpacing.md
            ) {
                ForEach(group.capsules, id: \.id) { capsule in
                    NavigationLink(value: capsule.id) {
                        CapsuleRow(capsule: capsule)
                    }
                    // 同列表模式 —— 移默认高亮，并带按下下沉手感。
                    .buttonStyle(.pressableCard)
                    .contextMenu { capsuleContextMenu(capsule) }
                }
            }
        }
        .padding(.horizontal, VoxlueSpacing.lg)
        // 滚动惯性 —— 段落滑入/滑出视口时轻微降透明与缩放，
        // 像相纸从暗处被推到灯下（§11.1 微动画：滚动惯性）。
        .scrollTransition(axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.75)
                .scaleEffect(phase.isIdentity ? 1 : 0.98)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// contact-sheet 首切提示横幅 —— MarginNote 形态 + 朱红「知道了」按钮，
    /// 关一次写 @AppStorage，下次再切到 grid 不再出现。
    /// grid 没 List 的右滑手势，靠 contextMenu 兜底；这条提示是把 iOS 用户
    /// 「先试右滑」的肌肉记忆转向「长按」的一次性引导。
    private var contactSheetHintBanner: some View {
        HStack(alignment: .top, spacing: VoxlueSpacing.md) {
            MarginNote("长按一张可分享或划掉")
            Spacer(minLength: VoxlueSpacing.sm)
            Button(action: dismissContactSheetHint) {
                Text("知道了")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.vermillion)
                    .padding(.horizontal, VoxlueSpacing.sm)
                    .padding(.vertical, VoxlueSpacing.xs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("我知道了，关闭提示")
        }
        // 整块合并成单元素 —— MarginNote 短画 + 文字 + 按钮一次读完，
        // 而不是三段散元素让人摸不清「这是一条可关闭的提示」（#86）。
        // .combine 会把子按钮动作降为 rotor 自定义操作，故补一个默认
        // accessibilityAction，保证 hint 里说的「双击关闭」真的可用。
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint("双击「知道了」可关闭此提示")
        .accessibilityAction { dismissContactSheetHint() }
    }

    /// 关闭 contact-sheet 首切提示 —— 可视按钮与 VoiceOver 默认操作共用一份实现。
    private func dismissContactSheetHint() {
        withAnimation(.easeOut(duration: 0.25)) {
            contactSheetHintSeen = true
        }
    }

    /// 列表与 contact-sheet 共享的 contextMenu 内容 —— 行为契约一致，避免一份在
    /// inline 写法里漂移、另一份在 grid 里漂移。
    @ViewBuilder private func capsuleContextMenu(_ capsule: VoxlueData.Capsule) -> some View {
        if let data = capsule.audioData, !data.isEmpty {
            ShareLink(
                item: data,
                preview: SharePreview(
                    capsule.title.isEmpty ? "（无题）" : capsule.title
                )
            )
        }
        Button(role: .destructive) {
            confirmingDelete = capsule
        } label: {
            Label("划掉", systemImage: "trash")
        }
    }

    /// 布局切换菜单。Menu + Picker —— iOS 标准的「藏进 chrome」形态，
    /// label 用当前选择的 icon，按下展开两个选项让人一眼读懂。
    /// label icon / Picker icon / enum 三处全共用 `ShelfLayout.icon`，
    /// 新增 case 只需在 enum 上同步一条，避免漂移。
    private var layoutMenu: some View {
        Menu {
            Picker("样片墙布局", selection: layoutBinding) {
                ForEach(ShelfLayout.allCases, id: \.self) { option in
                    Label(option.label, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            Image(systemName: layout.icon)
                .foregroundStyle(VoxlueColor.ink)
        }
        .accessibilityLabel("切换样片墙布局")
    }

    /// AppStorage 存的是 rawValue String —— 给 Picker 一只
    /// `Binding<ShelfLayout>` 适配器，读经 `layout`、写则拆回 rawValue。
    private var layoutBinding: Binding<ShelfLayout> {
        Binding(
            get: { layout },
            set: { layoutRaw = $0.rawValue }
        )
    }
}

/// 样片墙布局枚举 —— 文件级私有（仅 ShelfView 与其 Picker tag 用）。
/// rawValue 直接进 AppStorage；中文 label / SF Symbol icon 都在枚举上，新增 case
/// 只需补这一条，layoutMenu 自动 enumerate ShelfLayout.allCases 拿到新选项。
private enum ShelfLayout: String, CaseIterable {
    case list           // 单列 PhotoCard，按时间分段
    case contactSheet   // 2 列网格小样张，按时间分段

    /// Picker 与 a11y 标签的中文显示名 —— 「列表 / 小样张」摄影术语，
    /// 不混英文 chrome（commit 前是「contact-sheet」原词，与「列表」字面不齐）。
    var label: String {
        switch self {
        case .list:         "列表"
        case .contactSheet: "小样张"
        }
    }

    /// SF Symbol 标识 —— Menu label / Picker label icon / 未来其他入口共用一份。
    var icon: String {
        switch self {
        case .list:         "rectangle.grid.1x2"
        case .contactSheet: "square.grid.2x2"
        }
    }
}

#Preview {
    ShelfView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
