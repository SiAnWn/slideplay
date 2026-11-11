import SwiftUI

/// 竖向翻页：ScrollView + 分页行为。
/// 用本地 @State scrollID 作为滚动位置的权威来源（这是程序化跳页的可靠写法），
/// 再与 engine.current 双向同步：用户滑动 → 更新引擎；引擎跳页(自动播放/选片) → 驱动滚动。
struct PagerView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var engine: PlayerEngine

    @State private var scrollID: Int?

    var body: some View {
        let playlist = store.playlist
        ZStack {
            Color.black

            if playlist.count > 0 {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<playlist.count, id: \.self) { i in
                            if let item = playlist.item(at: i) {
                                VideoPageView(index: i, item: item)
                                    .id(i)
                                    .containerRelativeFrame([.horizontal, .vertical])
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollID)
                .onAppear {
                    if scrollID == nil { scrollID = engine.current }
                }
                .onChange(of: scrollID) { _, new in
                    if let n = new, n != engine.current { engine.setCurrent(n) }
                }
                .onChange(of: engine.current) { _, new in
                    if scrollID != new { scrollID = new }
                }
            } else {
                Text("当前片单为空")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .ignoresSafeArea()
    }
}
