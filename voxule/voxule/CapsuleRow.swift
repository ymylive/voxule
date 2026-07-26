import SwiftUI
import VoxlueData
import VoxlueDesign
import VoxlueServices   // Preview 用 FakeAudioRecording.fakeWaveform

/// 样片墙的一张相片 —— 按胶囊状态分两种形态：
/// - `.buried`：NegativeCard 反相（未显影、影像偏淡、深底亮字）
/// - 其余状态：PhotoCard 正像（已显影、亮底深字、朱章覆盖状态）
struct CapsuleRow: View {
    let capsule: VoxlueData.Capsule

    var body: some View {
        if capsule.state == .buried {
            NegativeCard(title: displayTitle, meta: metaLine,
                         seal: sealKind, sealDelay: stampDelay) {
                // NegativeCard 影像区永远是负片黑底，波形 tint 用固定 light，
                // 不跟随 colorScheme 翻面。
                WaveformView(
                    samples: capsule.waveform.isEmpty
                        ? [Float](repeating: 0.08, count: 64)
                        : capsule.waveform,
                    tint: VoxlueColor.darkroomGrayLight
                )
                .padding(.horizontal, VoxlueSpacing.lg)
            }
        } else {
            PhotoCard(title: displayTitle, meta: metaLine,
                      seal: sealKind, sealDelay: stampDelay) {
                // PhotoCard 图像区永远是负片黑底，同理用固定 light 端。
                WaveformView(
                    samples: capsule.waveform.isEmpty
                        ? [Float](repeating: 0.08, count: 64)
                        : capsule.waveform,
                    tint: VoxlueColor.paperHighlightLight
                )
                .padding(.horizontal, VoxlueSpacing.lg)
            }
        }
    }

    /// 按 capsule.id 散布的 0~0.2 秒延迟 —— 同屏多张片不会同步盖章，
    /// 读上去像「逐张冲洗」的级联，而不是一齐 twitch。
    private var stampDelay: Double {
        Double(abs(capsule.id.hashValue) % 6) * 0.04
    }

    private var displayTitle: String {
        capsule.title.isEmpty ? "（无题）" : capsule.title
    }

    /// 片基小字 —— 锁类型 · 时长 · 地点。
    private var metaLine: String {
        var parts: [String] = [lockLabel]
        if capsule.duration > 0 {
            parts.append(durationString)
        }
        if let place = capsule.placeName, !place.isEmpty {
            parts.append(place)
        }
        return parts.joined(separator: " · ")
    }

    private var durationString: String {
        let total = Int(capsule.duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var lockLabel: String {
        switch capsule.lock.kind {
        case .place: "地点锁"
        case .date: "时间锁"
        case .mood: "情绪锁"
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

// 长字段回归（§11.1）：真实数据路径下的 title 尾截 + meta lineLimit(2) 换行 ——
// PhotoCard / NegativeCard 的 Preview 盯组件本身，这里盯 metaLine 拼接后的整串。
#Preview("长题长地名 · 列表全宽") {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        VStack(spacing: VoxlueSpacing.md) {
            CapsuleRow(capsule: VoxlueData.Capsule(
                title: "外婆在厨房里一边炒菜一边哼的那首老歌",
                duration: 756,
                waveform: FakeAudioRecording.fakeWaveform,
                state: .developed,
                lock: .place(latitude: 31.2, longitude: 121.4,
                             radius: 100, placeName: "上海市徐汇区衡山路八号老洋房的天井")
            ))
            CapsuleRow(capsule: VoxlueData.Capsule(
                title: "潜伏中的长标题也一样要被优雅地截断掉",
                duration: 48,
                waveform: FakeAudioRecording.fakeWaveform,
                state: .buried,
                lock: .place(latitude: 39.9, longitude: 116.4,
                             radius: 150, placeName: "北京市东城区景山前街四号筒子河边")
            ))
        }
        .padding(VoxlueSpacing.lg)
    }
}

#Preview("长题长地名 · contact-sheet 半宽") {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        HStack(alignment: .top, spacing: VoxlueSpacing.md) {
            CapsuleRow(capsule: VoxlueData.Capsule(
                title: "外婆在厨房里哼的那首老歌",
                duration: 756,
                waveform: FakeAudioRecording.fakeWaveform,
                state: .developed,
                lock: .place(latitude: 31.2, longitude: 121.4,
                             radius: 100, placeName: "上海市徐汇区衡山路八号老洋房的天井")
            ))
            CapsuleRow(capsule: VoxlueData.Capsule(
                title: "短题",
                duration: 48,
                waveform: FakeAudioRecording.fakeWaveform,
                state: .opened,
                lock: .mood(notBefore: nil)
            ))
        }
        .padding(VoxlueSpacing.lg)
    }
}
