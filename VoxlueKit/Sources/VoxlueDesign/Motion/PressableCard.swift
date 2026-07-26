import SwiftUI

/// 相纸按下手感 —— 指尖按住一张相片时，它轻轻往下沉一点。
/// 缩放 0.98 + 透明度 0.96，spring 快起快落；松手即回弹。
/// 给样片墙 / 圈列表这类「一卡一链接」的行用，取代裸 `.plain`：
/// `.plain` 只是移除系统高亮，按下去毫无反馈，像按在玻璃柜面上。
public struct PressableCardStyle: ButtonStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.8),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == PressableCardStyle {
    /// `.buttonStyle(.pressableCard)` —— 相纸按下手感。
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

#Preview("按下手感") {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        Button {} label: {
            PaperCard {
                VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                    Text("按住我试试")
                        .font(VoxlueTypography.serifTitle)
                        .foregroundStyle(VoxlueColor.ink)
                    Text("按下去会轻轻下沉，松手回弹。")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.graphite)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.pressableCard)
        .padding(VoxlueSpacing.xl)
    }
}
