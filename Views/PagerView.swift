import SwiftUI

/// 竖向翻页：SwiftUI ScrollView + 分页行为。
/// 每页一个 VideoPageView；当前页由 engine.current 双向同步。
/// 注意：页内手势只用"点击/长按"这类不消费拖拽的手势，避免挡住上下滑。
struct PagerView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var engine: PlayerEngine

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
                .scrollPosition(id: Binding<Int?>(
                    get: { engine.current },
                    set: { if let v = $0 { engine.setCurrent(v) } }
                ))
            } else {
                Text("当前片单为空")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .ignoresSafeArea()
    }
}
