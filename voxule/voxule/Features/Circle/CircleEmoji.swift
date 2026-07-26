import Foundation

/// 圈 / 成员头像 emoji 的稳定映射。
///
/// 为什么不用 `String.hashValue`：Swift 的字符串 hash 每次进程启动随机加种
///（SipHash），「同名稳定」只在单次运行内成立 —— 重启 App 头像就全换
///（#85 dark 巡检两次启动「家」从 👨‍👩‍👧 变 🌿 的实证）。改用 FNV-1a：
/// 纯算术、跨进程跨设备稳定，同名永远落同一枚。
enum CircleEmoji {

    /// 圈头像池 —— 家、自然、夜、茶、相机几种「圈」的氛围（§11.1 扩池）。
    /// 改池子前注意：池长决定 hash 落点，同名圈的 emoji 会随之漂移，不影响数据。
    static let circlePool: [String] = [
        "🏠", "👨‍👩‍👧", "👫", "🌿", "🎵", "🌙", "🍵", "🌊", "🕯", "📷",
        "🌻", "🍂", "⛰️", "🐚", "🎐", "🧺", "🪁", "🌾", "🏮", "📻",
        "🧶", "🍊", "🌸", "☂️",
    ]

    /// 成员头像池 —— 人物为主，杂一点温和的身份气质。
    static let memberPool: [String] = [
        "👤", "🧑", "👩", "👨", "🧒", "👵", "👴", "🧓", "👶", "🧑‍🎓", "🧑‍🍳", "🧑‍🎨",
        "🧑‍🌾", "🧑‍🏫", "👩‍🦱", "👨‍🦱", "👩‍🦳", "🧑‍🦰", "👱", "🧕", "👲", "🧑‍🚀",
    ]

    /// 由圈名映射头像。空名 fallback 一个空心圆点。
    static func circleEmoji(forName name: String) -> String {
        pick(from: circlePool, byName: name, empty: "○")
    }

    /// 由成员名映射头像。空名 fallback 通用人形。
    static func memberEmoji(forName name: String) -> String {
        pick(from: memberPool, byName: name, empty: "👤")
    }

    private static func pick(from pool: [String], byName name: String, empty: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return empty }
        return pool[Int(fnv1a(trimmed) % UInt64(pool.count))]
    }

    /// FNV-1a 64 位 —— 短字符串的稳定散列，够均匀且实现只有四行。
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
