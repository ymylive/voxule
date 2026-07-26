import SwiftUI
import VoxlueDesign

/// 「关于 voxlue」—— 设计哲学落地页。
/// 一卷可滚动的暗房卷宗：标题、副题、哲学段、调色板、批注、版本号。
/// 整体压在 PaperBackground 上，保持纸感的物质性。
struct AboutView: View {
    var body: some View {
        ZStack {
            PaperBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: VoxlueSpacing.xl) {
                    hero
                    tagline
                    philosophy
                    paletteStrip
                    // 独立居中场景不再用 MarginNote ——「— xxx」文本和 MarginNote
                    // 自带的朱红短画会形成双重 dash，且 dash 在左、文字在右导致整体
                    // 重心偏右、与居中容器不和谐。改纯居中 Caveat 文字，保留朱红声。
                    Text("这是陪伴，不是提醒事项。")
                        .font(VoxlueTypography.annotation)
                        .foregroundStyle(VoxlueColor.vermillion)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    catalogLink
                    version
                }
                .padding(.horizontal, VoxlueSpacing.xl)
                .padding(.vertical, VoxlueSpacing.xxl)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 分块

    /// Hero —— Crimson 斜体大字 "voxlue"。
    private var hero: some View {
        Text("voxlue")
            .font(VoxlueTypography.display)
            .foregroundStyle(VoxlueColor.ink)
            .frame(maxWidth: .infinity)
    }

    /// 副题 —— 思源宋区段标题。
    private var tagline: some View {
        Text("声音的暗房")
            .font(VoxlueTypography.heading)
            .foregroundStyle(VoxlueColor.ink)
            .frame(maxWidth: .infinity)
    }

    /// 哲学段 —— 三行思源宋正文，包在纸卡里。
    private var philosophy: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
                Text("voxlue 是一座私人暗房。")
                Text("你把一段声音录下来 —— 它是负片，潜伏在某处。")
                Text("等一个时刻、一个地点、或者只是某个心情，它会自己显影，回到你面前。")
            }
            .font(VoxlueTypography.serifBody)
            .foregroundStyle(VoxlueColor.ink)
            .lineSpacing(VoxlueTypography.Step.body.lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 调色板条 —— 八色 swatch + 思源宋图注。
    private var paletteStrip: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            Text("纸 · 墨 · 朱")
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: VoxlueSpacing.md) {
                    // adaptivePalette 而非 palette —— 后者钉死 light 端，dark 下
                    // 会与整页翻面自相矛盾（#85 巡检发现纸基 swatch 在暗房里发亮）。
                    ForEach(Array(zip(VoxlueColor.adaptivePalette, VoxlueColor.paletteNames).enumerated()), id: \.offset) { _, pair in
                        VStack(spacing: VoxlueSpacing.xs) {
                            RoundedRectangle(cornerRadius: VoxlueRadius.stamp, style: .continuous)
                                .fill(pair.0)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VoxlueRadius.stamp, style: .continuous)
                                        .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.5)
                                )
                            Text(pair.1)
                                .font(VoxlueTypography.caption)
                                .foregroundStyle(VoxlueColor.graphite)
                        }
                        // VoiceOver 否则会先念 8 个 unlabeled 矩形再念 8 个图注；
                        // combine 后每色一组「色名」一条朗读。
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(pair.1)
                    }
                }
                .padding(.vertical, VoxlueSpacing.xs)
            }
        }
    }

    /// 设计系统入口 —— 朱色胶囊，推 DesignCatalogView。
    /// 摆在 MarginNote 之后、version 之前；保持「subtle 但明显可点」的中间地带。
    private var catalogLink: some View {
        NavigationLink {
            DesignCatalogView()
        } label: {
            HStack(spacing: VoxlueSpacing.sm) {
                Image(systemName: "swatchpalette")
                    .foregroundStyle(VoxlueColor.vermillion)
                Text("看看完整设计系统 →")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.vermillion)
            }
            .padding(.horizontal, VoxlueSpacing.md)
            .padding(.vertical, VoxlueSpacing.sm)
            .background(VoxlueColor.paperHighlight, in: Capsule())
            .voxlueShadow(.paper)
        }
        .buttonStyle(.plain)
        .padding(.top, VoxlueSpacing.lg)
    }

    /// 版本号 —— Space Mono 元数据，暗房灰。
    private var version: some View {
        Text("voxlue · VoxlueDesign \(VoxlueDesign.version)")
            .font(VoxlueTypography.meta)
            .foregroundStyle(VoxlueColor.darkroomGray)
            .frame(maxWidth: .infinity)
            .padding(.top, VoxlueSpacing.md)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
