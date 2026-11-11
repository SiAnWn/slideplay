import SwiftUI
import UIKit

/// 普通宿主控制器：把 UIPageViewController 作为子控制器嵌入。
/// （直接把容器型控制器交给 UIViewControllerRepresentable 常常显示空白，包一层最稳。）
final class PagerHostViewController: UIViewController {
    let pager = PagerViewController()
    weak var engine: PlayerEngine?
    weak var store: LibraryStore?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(pager)
        pager.view.frame = view.bounds
        pager.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pager.view)
        pager.didMove(toParent: self)

        if let engine, let store {
            pager.configure(engine: engine, store: store)
            pager.show(index: engine.current)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pager.view.frame = view.bounds
    }
}

/// 把 UIKit 竖向翻页容器包进 SwiftUI；当前页与 engine.current 双向同步。
struct PagerView: UIViewControllerRepresentable {
    @EnvironmentObject private var engine: PlayerEngine
    @EnvironmentObject private var store: LibraryStore

    func makeUIViewController(context: Context) -> PagerHostViewController {
        let host = PagerHostViewController()
        host.engine = engine
        host.store = store
        return host
    }

    func updateUIViewController(_ host: PagerHostViewController, context: Context) {
        host.engine = engine
        host.store = store
        host.pager.configure(engine: engine, store: store)
        if host.pager.currentIndex != engine.current {
            host.pager.show(index: engine.current)
        }
    }
}
