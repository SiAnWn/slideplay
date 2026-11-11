import UIKit
import SwiftUI

/// 竖向翻页容器（UIPageViewController），每页是一个 SlidePlayerViewController。
final class PagerViewController: UIPageViewController {
    weak var engine: PlayerEngine?
    weak var store: LibraryStore?
    private(set) var currentIndex: Int = 0

    init() {
        super.init(transitionStyle: .scroll,
                   navigationOrientation: .vertical,
                   options: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func configure(engine: PlayerEngine, store: LibraryStore) {
        self.engine = engine
        self.store = store
        dataSource = self
        delegate = self
    }

    private func makeVC(_ index: Int) -> SlidePlayerViewController? {
        guard let engine, let store, let item = store.playlist.item(at: index) else { return nil }
        return SlidePlayerViewController(index: index, item: item, engine: engine, store: store)
    }

    /// 跳到指定页（外部切页 / 自动播放下一个 / 搜索跳转）。
    func show(index: Int, animated: Bool = false) {
        guard let vc = makeVC(index) else { return }
        setViewControllers([vc], direction: .forward, animated: animated)
        currentIndex = index
    }
}

extension PagerViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pvc: UIPageViewController,
                            viewControllerBefore vc: UIViewController) -> UIViewController? {
        guard let cur = vc as? SlidePlayerViewController else { return nil }
        return makeVC(cur.index - 1)
    }

    func pageViewController(_ pvc: UIPageViewController,
                            viewControllerAfter vc: UIViewController) -> UIViewController? {
        guard let cur = vc as? SlidePlayerViewController else { return nil }
        return makeVC(cur.index + 1)
    }

    func pageViewController(_ pvc: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed,
              let vc = pvc.viewControllers?.first as? SlidePlayerViewController else { return }
        currentIndex = vc.index
        engine?.setCurrent(vc.index)
    }
}
