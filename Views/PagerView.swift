import SwiftUI

/// 把 UIKit 的竖向翻页容器（PagerViewController）包进 SwiftUI。
/// 当前页与 engine.current 双向同步：用户滑动 → 更新 engine；外部跳转/自动播放 → 驱动翻页。
struct PagerView: UIViewControllerRepresentable {
    @EnvironmentObject private var engine: PlayerEngine
    @EnvironmentObject private var store: LibraryStore

    func makeUIViewController(context: Context) -> PagerViewController {
        let pvc = PagerViewController()
        pvc.configure(engine: engine, store: store)
        pvc.show(index: engine.current)
        return pvc
    }

    func updateUIViewController(_ pvc: PagerViewController, context: Context) {
        pvc.configure(engine: engine, store: store)   // 保持引用最新
        if pvc.currentIndex != engine.current {
            pvc.show(index: engine.current)
        }
    }
}
