import Testing
@testable import voxule

// CircleEmoji 稳定映射 —— 核心承诺是「同名跨进程稳定」。
// String.hashValue 每次启动随机加种，旧实现的头像重启就漂（#85 巡检实证）；
// 这里用固定向量钉死 FNV-1a 的输出，算法被误改会立刻红。

@Test func fnv1aMatchesKnownVectors() {
    #expect(CircleEmoji.fnv1a("家") == 0x1a3a_511b_667d_88d4)
    #expect(CircleEmoji.fnv1a("外婆") == 0xc256_5aa5_35d9_6f2a)
    #expect(CircleEmoji.fnv1a("大学室友") == 0x3cc1_01d5_3bfb_c325)
}

@Test func sameNameAlwaysSameEmoji() {
    let first = CircleEmoji.circleEmoji(forName: "家")
    #expect((0..<100).allSatisfy { _ in CircleEmoji.circleEmoji(forName: "家") == first })
    #expect(CircleEmoji.circleEmoji(forName: " 家 ") == first)   // 首尾空白不影响落点
}

@Test func emptyNamesFallBack() {
    #expect(CircleEmoji.circleEmoji(forName: "") == "○")
    #expect(CircleEmoji.circleEmoji(forName: "  ") == "○")
    #expect(CircleEmoji.memberEmoji(forName: "") == "👤")
}

@Test func poolsAreNonEmptyAndMappingsLandInPool() {
    #expect(!CircleEmoji.circlePool.isEmpty)
    #expect(!CircleEmoji.memberPool.isEmpty)
    for name in ["家", "外婆", "大学室友", "abc", "🌊圈"] {
        #expect(CircleEmoji.circlePool.contains(CircleEmoji.circleEmoji(forName: name)))
        #expect(CircleEmoji.memberPool.contains(CircleEmoji.memberEmoji(forName: name)))
    }
}
