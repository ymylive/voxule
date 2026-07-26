import SwiftUI

/// 负片 —— 一枚埋下后、尚未显影的胶囊的样子。
/// 反相：深底亮字，标题被「冲淡」。胶囊显影后会换成 PhotoCard。
public struct NegativeCard<Image: View>: View {
    private let title: String
    private let meta: String
    private let seal: SealStamp.Kind?
    private let sealDelay: Double
    private let image: Image

    /// - Parameters:
    ///   - seal: 可选的朱章。给的话盖在反相影像区右上角；仍区分锁类型。
    ///   - sealDelay: 朱章入场延迟，与 PhotoCard 用法一致。
    public init(
        title: String,
        meta: String,
        seal: SealStamp.Kind? = nil,
        sealDelay: Double = 0,
        @ViewBuilder image: () -> Image
    ) {
        self.title = title
        self.meta = meta
        self.seal = seal
        self.sealDelay = sealDelay
        self.image = image()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            // 影像区 —— 与 PhotoCard 150pt 对齐，混排时行高一致。
            // 反相态用 darkroomGrayLight 给片孔色，留在深底上仍可识别。
            // 整张 NegativeCard 永远是负片黑底，文字 / 片孔都不参与 colorScheme 翻面，
            // 否则 dark 下会变黑底黑字。
            image
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .opacity(0.55)               // 未显影 —— 影像偏淡。
                .overlay(FilmPerforations(edge: .top, holeColor: VoxlueColor.darkroomGrayLight))
                .overlay(FilmPerforations(edge: .bottom, holeColor: VoxlueColor.darkroomGrayLight))
                .overlay(alignment: .topTrailing) {
                    if let seal {
                        SealStamp(seal, delay: sealDelay)
                            .padding(.top, FilmPerforations.safeContentInset)
                            .padding(.trailing, VoxlueSpacing.sm)
                    }
                }

            Text(title)
                .font(VoxlueTypography.serifTitle)
                .foregroundStyle(VoxlueColor.inkOnDark)
                .lineLimit(1)
            // meta 在样片墙单列下一行即够，但 contact-sheet 半宽场景下
            // 「时间锁 · 0:48 · 北京市朝阳区xxx」会截断地点 —— 用户最敏感的一项。
            // 与 PhotoCard 同步 lineLimit(2)。
            Text(meta)
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.darkroomGrayLight)
                .lineLimit(2)
        }
        .padding(VoxlueSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VoxlueRadius.photo, style: .continuous)
                .fill(VoxlueColor.negativeBlack)
        )
        .voxlueShadow(.photo)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        NegativeCard(title: "潜伏中的一段声", meta: "已埋下 · 等一个地点") {
            Rectangle().fill(VoxlueColor.graphite)
        }
        .padding(VoxlueSpacing.xl)
    }
}

// 长字段回归（§11.1）：title 应尾截、meta 两行内换行保地名，与 PhotoCard 同一套数学。
// 半宽两列是 contact-sheet 的真实约束 —— 改片基排版先看这里。
#Preview("长题长 meta · 半宽两列") {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        HStack(alignment: .top, spacing: VoxlueSpacing.md) {
            NegativeCard(
                title: "外婆在厨房里哼的那首老歌",
                meta: "地点锁 · 12:36 · 上海市徐汇区衡山路八号老洋房的天井",
                seal: .buried
            ) {
                Rectangle().fill(VoxlueColor.graphite)
            }
            NegativeCard(
                title: "短题",
                meta: "情绪锁 · 0:48",
                seal: .buried
            ) {
                Rectangle().fill(VoxlueColor.graphite)
            }
        }
        .padding(VoxlueSpacing.lg)
    }
}
