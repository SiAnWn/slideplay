import SwiftUI

/// 主题色集中管理。当前方案：B 蓝粉。
/// 所有强调色、开关、收藏心形、进度条渐变、主按钮都从这里取值。
/// 想换回 A 蓝紫：把 accent 改为 #5E6BF0、heart 改为 #FF4A78、gradient 终点改为紫色即可。
enum Theme {
    // —— 方案 B：蓝粉（当前启用）——
    static let accent = Color(red: 0.15, green: 0.55, blue: 0.98)   // #268CF9 亮蓝
    static let heart = Color(red: 0.98, green: 0.29, blue: 0.55)    // #FA4A8C 粉

    /// 用于进度条、主按钮的渐变：蓝 → 粉
    static let gradient = LinearGradient(
        colors: [Color(red: 0.15, green: 0.55, blue: 0.98),   // #268CF9 蓝
                 Color(red: 0.98, green: 0.29, blue: 0.55)],  // #FA4A8C 粉
        startPoint: .topLeading, endPoint: .bottomTrailing)
}
