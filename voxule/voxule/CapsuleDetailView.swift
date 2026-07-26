import SwiftUI
import SwiftData
import UIKit
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 胶囊详情 + 回放。改用相片卡 + 纸基容器：顶部 PhotoCard 露图像，
/// 下面纸卡放回放控件与元数据。
struct CapsuleDetailView: View {
    let capsule: VoxlueData.Capsule

    @Environment(\.appEnvironment) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// 共享触发引擎 —— 开启后结束 Live Activity，删除后取消通知并重排围栏（D9/D10）。
    /// 可选：预览/未注入环境时为 nil，调用即无操作。
    @Environment(AppDependencies.self) private var dependencies: AppDependencies?

    @State private var loaded = false
    @State private var confirmingDelete = false
    @State private var showingNoteEditor = false
    @State private var editingNote = ""
    @State private var showingRename = false
    @State private var editingTitle = ""
    @State private var showingCirclePicker = false
    /// 上次触 haptic 时的 progress —— 用来按 5% 步长去抖。
    @State private var lastHapticProgress: Double = 0

    private var player: any AudioPlaying { env.player }

    var body: some View {
        ZStack {
            PaperBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: VoxlueSpacing.xl) {
                    photoHero
                    playbackControls
                    metadata
                    developingTimeline
                    NeighborNav(currentID: capsule.id)
                }
                .padding(VoxlueSpacing.lg)
            }
        }
        .navigationTitle(capsule.title.isEmpty ? "（无题）" : capsule.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear(perform: prepare)
        .onDisappear { player.pause() }
        .alert("划掉这枚胶囊？", isPresented: $confirmingDelete) {
            Button("划掉", role: .destructive) { performDelete() }
            Button("不了", role: .cancel) {}
        } message: {
            Text("声音会从样片墙、地图和声音圈里消失。")
        }
        .sheet(isPresented: $showingNoteEditor) { noteEditor }
        .sheet(isPresented: $showingRename) { renameSheet }
        .sheet(isPresented: $showingCirclePicker) {
            NavigationStack {
                Form {
                    Section {
                        CirclePickerView(selectedCircleID: Binding(
                            get: { capsule.circleID },
                            set: { newID in
                                // 经 store 同写 circleID + circle 关系（D7）。
                                try? CapsuleStore(context: context).assignCircle(capsule, circleID: newID)
                            }
                        ))
                    } header: {
                        Text("移到").font(VoxlueTypography.caption).foregroundStyle(VoxlueColor.graphite).textCase(nil)
                    } footer: {
                        Text("移到「自己」会从所有声音圈里取消归属。")
                            .font(VoxlueTypography.caption)
                            .foregroundStyle(VoxlueColor.darkroomGray)
                    }

                    Section {
                        Button("移到「自己」", role: .destructive) {
                            try? CapsuleStore(context: context).assignCircle(capsule, circleID: nil)
                            showingCirclePicker = false
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(PaperBackground().ignoresSafeArea())
                .navigationTitle("改个圈")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("好") { showingCirclePicker = false }
                            .font(VoxlueTypography.serifBody)
                            .foregroundStyle(VoxlueColor.vermillion)
                    }
                }
            }
        }
    }

    /// 顶栏右上：分享 + 划掉。分享只在确有音频时露出。
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let audioData = capsule.audioData, !audioData.isEmpty {
                ShareLink(
                    item: audioData,
                    preview: SharePreview(displayTitle)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(VoxlueColor.ink)
                }
                .accessibilityLabel("分享")
            }

            Menu {
                Button {
                    editingTitle = capsule.title
                    showingRename = true
                } label: {
                    Label("改个名", systemImage: "pencil")
                }
                Button {
                    showingCirclePicker = true
                } label: {
                    Label("改个圈", systemImage: "person.2.wave.2")
                }
                Divider()
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("划掉", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(VoxlueColor.ink)
            }
            .accessibilityLabel("更多")
        }
    }

    /// 划掉：先停播放器（不然 AVAudioPlayer 还在抓 data）→ store.delete → dismiss。
    private func performDelete() {
        player.pause()
        let id = capsule.id
        do {
            try CapsuleStore(context: context).delete(capsule)
        } catch {
            // 兜底：store 失败就直接走 context，免得卡死返回不了。
            context.delete(capsule)
            try? context.save()
        }
        // 删除后取消该胶囊待发通知、结束 Live Activity，并按剩余胶囊重排围栏（D10）。
        Task { await dependencies?.engine.discard(capsuleID: id) }
        dismiss()
    }

    /// 顶部相片 —— 按状态分流：
    /// .buried 显未显影的 NegativeCard 反相；其余走 PhotoCard 已显影。
    @ViewBuilder
    private var photoHero: some View {
        if capsule.state == .buried {
            NegativeCard(title: displayTitle, meta: headerMeta, seal: sealKind) {
                // 影像区永远是负片黑底，波形 tint 用固定 light。
                WaveformView(
                    samples: capsule.waveform.isEmpty
                        ? [Float](repeating: 0.1, count: 80)
                        : capsule.waveform,
                    progress: player.progress,
                    tint: VoxlueColor.darkroomGrayLight
                )
                .padding(.horizontal, VoxlueSpacing.lg)
            }
        } else {
            PhotoCard(title: displayTitle, meta: headerMeta, seal: sealKind) {
                WaveformView(
                    samples: capsule.waveform.isEmpty
                        ? [Float](repeating: 0.1, count: 80)
                        : capsule.waveform,
                    progress: player.progress,
                    tint: VoxlueColor.paperHighlightLight
                )
                .padding(.horizontal, VoxlueSpacing.lg)
            }
        }
    }

    private var playbackControls: some View {
        PaperCard {
            VStack(spacing: VoxlueSpacing.lg) {
                // 滑杆区 —— 进度 + 双字体时间码 + 上下文批注。
                VStack(spacing: VoxlueSpacing.sm) {
                    Slider(
                        value: Binding(
                            get: { player.progress },
                            set: { newValue in
                                // 每跨 5% 触一次 haptic —— 拖到位有节奏，不会满频抖。
                                let step = 0.05
                                if abs(newValue - lastHapticProgress) >= step {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    lastHapticProgress = newValue
                                }
                                player.seek(toProgress: newValue)
                            }
                        ),
                        in: 0...1
                    )
                    .tint(VoxlueColor.vermillion)

                    HStack(spacing: VoxlueSpacing.sm) {
                        // 左：Crimson Pro 计数器 —— 像胶片片头的西文计时。
                        Text(progressTimeString)
                            .font(VoxlueTypography.serifLatin(.body))
                            .foregroundStyle(VoxlueColor.ink)
                        // 播放时朱红圆点呼吸 —— 中段分隔。
                        // phaseAnimator 自动在 phases 间无限循环；不需要外面手动反复
                        // toggle @State 才能 repeatForever 生效（这是原写法的 bug）。
                        if player.isPlaying {
                            Circle()
                                .fill(VoxlueColor.vermillion)
                                .frame(width: 5, height: 5)
                                .phaseAnimator([false, true]) { content, phase in
                                    content.opacity(phase ? 1.0 : 0.3)
                                } animation: { _ in
                                    .easeInOut(duration: 0.8)
                                }
                        }
                        Spacer()
                        // 右：Space Mono 时长 —— 元数据冷调。
                        Text(durationString)
                            .font(VoxlueTypography.meta)
                            .foregroundStyle(VoxlueColor.graphite)
                    }

                    if let note = playbackMarginNote {
                        MarginNote(note)
                            .padding(.top, VoxlueSpacing.xs)
                    }
                }

                // 按钮区 —— 朱红脉冲环包裹的播放/暂停。
                // 用 phaseAnimator 在 [false, true] 间循环，scale 在 1.0 ↔ 1.12 之间呼吸；
                // 仅在 isPlaying 时让 scale 落到 phase 上，否则强制回 1.0。
                ZStack {
                    Circle()
                        .stroke(
                            VoxlueColor.vermillion.opacity(player.isPlaying ? 0.35 : 0.18),
                            lineWidth: 2
                        )
                        .frame(width: 64, height: 64)
                        .phaseAnimator([false, true]) { content, phase in
                            content.scaleEffect(player.isPlaying && phase ? 1.12 : 1.0)
                        } animation: { _ in
                            .easeInOut(duration: 0.9)
                        }

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(VoxlueColor.vermillion)
                    }
                    .disabled(!loaded)
                    .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
                }
            }
        }
    }

    /// 滑杆下的上下文批注：读取失败 / 播放中 / 听到一半 / 否则隐藏。
    /// 读取失败走 inline 批注而不是 alert —— 进详情只是「看」，还没「听」，
    /// 一进门就弹 modal 是打脸（#85 巡检发现空音频胶囊进页即弹窗）。
    private var playbackMarginNote: String? {
        if !loaded {
            return "这段声音没能读出来。"
        } else if player.isPlaying {
            return "正在听 →"
        } else if player.progress > 0 {
            return "听到一半，可以接着"
        } else {
            return nil
        }
    }

    private var metadata: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                metadataRow(label: "锁", value: lockDetail)
                if let place = capsule.placeName {
                    metadataRow(label: "录于", value: place)
                }
                if let note = capsule.note, !note.isEmpty {
                    Button {
                        beginNoteEdit()
                    } label: {
                        metadataRow(label: "批注", value: note)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("编辑批注")
                } else {
                    Button {
                        beginNoteEdit()
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text("批注")
                                .font(VoxlueTypography.caption)
                                .foregroundStyle(VoxlueColor.graphite)
                                .frame(width: 48, alignment: .leading)
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(VoxlueColor.vermillion)
                            Text("写一条批注")
                                .font(VoxlueTypography.serifBody)
                                .foregroundStyle(VoxlueColor.vermillion)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("写一条批注")
                }
                metadataRow(
                    label: "埋于",
                    value: capsule.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    /// 显影 timeline —— 朱红两点：埋下 / 听到。
    /// 「听到」只在 openedAt 有值时才长出来；只有「埋下」时省略连接线，
    /// 免得空荡荡一根线吊在那。
    private var developingTimeline: some View {
        let hasOpened = capsule.openedAt != nil

        return PaperCard {
            HStack(alignment: .top, spacing: VoxlueSpacing.md) {
                // 左侧 rail —— 圆点 + 细线。固定 8pt 宽度，让右列文字对齐稳。
                VStack(spacing: 0) {
                    Circle()
                        .fill(VoxlueColor.vermillion)
                        .frame(width: 8, height: 8)

                    if hasOpened {
                        Rectangle()
                            .fill(VoxlueColor.vermillion.opacity(0.5))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)

                        Circle()
                            .fill(VoxlueColor.vermillion)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 8)
                .padding(.top, 4) // 让圆点和右侧 caption 的 baseline 视觉对齐

                // 右侧内容 —— 每个里程碑：caption 标签 + meta 日期。
                VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
                    timelineEntry(
                        label: "埋下",
                        date: capsule.createdAt
                    )

                    if let openedAt = capsule.openedAt {
                        timelineEntry(
                            label: "听到",
                            date: openedAt
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func timelineEntry(label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
            Text(label)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.ink)
            Text(date.formatted(date: .abbreviated, time: .shortened))
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.graphite)
        }
    }

    /// 批注编辑 sheet —— 纸基底 + 思源宋 TextField + 朱红保存按钮。
    private var noteEditor: some View {
        NavigationStack {
            ZStack {
                PaperBackground().ignoresSafeArea()

                TextField(
                    "写一条批注",
                    text: $editingNote,
                    axis: .vertical
                )
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.ink)
                .lineLimit(3...10)
                .padding(VoxlueSpacing.lg)
            }
            .navigationTitle("批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        showingNoteEditor = false
                    }
                    .foregroundStyle(VoxlueColor.graphite)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveNote()
                    }
                    .foregroundStyle(VoxlueColor.vermillion)
                }
            }
        }
    }

    private func beginNoteEdit() {
        editingNote = capsule.note ?? ""
        showingNoteEditor = true
    }

    private func saveNote() {
        capsule.note = editingNote.isEmpty ? nil : editingNote
        try? context.save()
        showingNoteEditor = false
    }

    /// 改名 sheet —— 纸基底 + Form section + 朱红保存。
    /// 这里只是 metadata —— 摄影师重贴标签，不动底片。
    private var renameSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("给这张声音起个名", text: $editingTitle)
                        .font(VoxlueTypography.serifBody)
                } header: {
                    Text("标题")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.graphite)
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PaperBackground().ignoresSafeArea())
            .navigationTitle("改个名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        showingRename = false
                    }
                    .foregroundStyle(VoxlueColor.graphite)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveTitle()
                    }
                    .foregroundStyle(VoxlueColor.vermillion)
                }
            }
        }
    }

    private func saveTitle() {
        capsule.title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
        showingRename = false
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.ink)
            Spacer()
        }
    }

    private func prepare() {
        // pause 先于空数据早退 —— 从正在播放的邻居切进一枚无音频胶囊时，
        // 旧声音不应继续放（评审指出的早退路径遗漏）。
        player.pause()
        guard let data = capsule.audioData, !data.isEmpty else {
            loaded = false
            return
        }
        do {
            // 每次 onAppear 都把本胶囊音频重新装入共享播放器：env.player 是全局单例，
            // 从邻居详情返回后它可能仍持有邻居的音频；旧的一次性 `!loaded` 守卫会跳过
            // 重装，导致按下播放放出的是邻居的声音、还把本枚错标成已听（D6）。
            try player.load(data)
            loaded = true
        } catch {
            loaded = false
        }
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
            markOpenedIfNeeded()
        }
    }

    /// 首次播放把胶囊状态推进到 opened。
    private func markOpenedIfNeeded() {
        guard capsule.state != .opened else { return }
        try? CapsuleStore(context: context).updateState(capsule, to: .opened)
        // 开启后结束可能仍在显示的灵动岛 Live Activity（D9）。
        let id = capsule.id
        Task { await dependencies?.engine.markOpened(capsuleID: id) }
    }

    private var displayTitle: String {
        capsule.title.isEmpty ? "（无题）" : capsule.title
    }

    /// 片基小字 —— 锁 · 时长 · 状态。
    private var headerMeta: String {
        var parts: [String] = [lockLabel]
        if capsule.duration > 0 {
            parts.append(durationString)
        }
        parts.append(capsule.state.displayLabel)
        return parts.joined(separator: " · ")
    }

    private var progressTimeString: String {
        timeString(player.progress * capsule.duration)
    }

    private var durationString: String { timeString(capsule.duration) }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var lockLabel: String {
        switch capsule.lockKind {
        case .place: "地点锁"
        case .date: "时间锁"
        case .mood: "情绪锁"
        }
    }

    private var lockDetail: String {
        switch capsule.lock {
        case .place(_, _, let radius, let placeName):
            let name = placeName.isEmpty ? "某个地方" : placeName
            return "走到「\(name)」附近 \(Int(radius))m"
        case .date(let target):
            let now = Date()
            if target > now {
                let days = Calendar.current.dateComponents([.day], from: now, to: target).day ?? 0
                return days == 0 ? "今天显影" : "还有 \(days) 天显影"
            } else {
                let days = Calendar.current.dateComponents([.day], from: target, to: now).day ?? 0
                return days == 0 ? "今天到期" : "已过期 \(days) 天"
            }
        case .mood:
            return "voxlue 觉得合适时浮现"
        }
    }

    private var sealKind: SealStamp.Kind {
        switch capsule.state {
        case .buried: .buried
        case .developing: .developing
        case .developed: .developed
        case .opened: .opened
        }
    }
}

/// 「上一枚 / 下一枚」导航 —— 独立子视图 + 自带 @Query（D22）。
/// 关键：把邻居定位的 O(n) `firstIndex` 扫描从父视图 body 里挪出来。父视图 body 因读
/// `player.progress` 每秒重算约 20 次；旧实现会跟着 20×/秒做全表扫描。本子视图只在
/// SwiftData 数据变化时才重算邻居，与回放进度彻底解耦。
private struct NeighborNav: View {
    let currentID: UUID

    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var allCapsules: [VoxlueData.Capsule]

    /// 在 createdAt 倒序的全表里定位当前胶囊。删除后可能是 nil。
    private var currentIndex: Int? {
        allCapsules.firstIndex(where: { $0.id == currentID })
    }

    /// 「上一枚」= 倒序表里的前一项（更新的一枚）；边界返回 nil。
    private var previousCapsule: VoxlueData.Capsule? {
        guard let idx = currentIndex, idx > 0 else { return nil }
        return allCapsules[idx - 1]
    }

    /// 「下一枚」= 倒序表里的后一项（更早的一枚）；边界返回 nil。
    private var nextCapsule: VoxlueData.Capsule? {
        guard let idx = currentIndex, idx + 1 < allCapsules.count else { return nil }
        return allCapsules[idx + 1]
    }

    var body: some View {
        HStack(spacing: VoxlueSpacing.lg) {
            if let prev = previousCapsule {
                NavigationLink {
                    CapsuleDetailView(capsule: prev)
                } label: {
                    navPill(systemImage: "chevron.left", text: "上一枚")
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let next = nextCapsule {
                NavigationLink {
                    CapsuleDetailView(capsule: next)
                } label: {
                    navPill(systemImage: "chevron.right", text: "下一枚", trailing: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, VoxlueSpacing.lg)
    }

    private func navPill(systemImage: String, text: String, trailing: Bool = false) -> some View {
        HStack(spacing: VoxlueSpacing.xs) {
            if !trailing { Image(systemName: systemImage) }
            Text(text)
            if trailing { Image(systemName: systemImage) }
        }
        .font(VoxlueTypography.caption)
        .foregroundStyle(VoxlueColor.vermillion)
        .padding(.horizontal, VoxlueSpacing.md)
        .padding(.vertical, VoxlueSpacing.sm)
        .background(VoxlueColor.paperHighlight, in: Capsule())
        .voxlueShadow(.paper)
    }
}

#Preview {
    NavigationStack {
        CapsuleDetailView(
            capsule: VoxlueData.Capsule(
                title: "咖啡馆的雨",
                audioData: Data("preview".utf8),
                duration: 8,
                waveform: FakeAudioRecording.fakeWaveform,
                state: .developed,
                lock: .date(.now)
            )
        )
    }
    .environment(\.appEnvironment, .preview())
    .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
