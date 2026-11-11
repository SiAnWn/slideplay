import SwiftUI
import Combine

/// 数据层：收藏、观看进度、播放模式、筛选、排序、列表与播放队列。
/// 全部持久化在 App 本地（Application Support/library.json），不联网。
final class LibraryStore: ObservableObject {
    enum SortKey: String, Codable, CaseIterable, Identifiable {
        case name
        case date
        case size
        var id: String { rawValue }
        var label: String {
            switch self {
            case .name: return "按文件名"
            case .date: return "按修改时间"
            case .size: return "按文件大小"
            }
        }
    }

    enum Filter: String, Codable {
        case all
        case favoritesOnly
    }

    @Published var videos: [VideoItem] = []
    @Published var favorites: Set<String> = []
    @Published var resumePositions: [String: Double] = [:]
    @Published var mode: Playlist.Mode = .sequential
    @Published var filter: Filter = .all
    @Published var sortKey: SortKey = .name

    private var shuffleSalt: Int = 0

    private static let saveURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SlidePlay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }()

    private var saveTask: Task<Void, Never>?

    private struct Snapshot: Codable {
        var favorites: [String] = []
        var resume: [String: Double] = [:]
        var mode: Playlist.Mode = .sequential
        var filter: Filter = .all
        var salt: Int = 0
        var sortKey: SortKey = .name
    }

    init() {
        load()
    }

    // MARK: - 列表与播放队列

    var sortedVideos: [VideoItem] {
        switch sortKey {
        case .name:
            return videos.sorted { a, b in
                let r = a.title.localizedStandardCompare(b.title)
                if r == .orderedAscending { return true }
                if r == .orderedDescending { return false }
                return a.modDate < b.modDate
            }
        case .date:
            return videos.sorted { $0.modDate > $1.modDate }
        case .size:
            return videos.sorted { $0.fileSize > $1.fileSize }
        }
    }

    var visibleVideos: [VideoItem] {
        filter == .favoritesOnly
            ? sortedVideos.filter { favorites.contains($0.stableID) }
            : sortedVideos
    }

    /// 随机顺序由 salt + 数量决定：只有手动"重新洗牌"或内容变化才会改变顺序。
    var playlist: Playlist {
        Playlist(items: visibleVideos,
                 mode: mode,
                 seed: mode == .shuffled ? "s\(shuffleSalt)-n\(visibleVideos.count)" : "")
    }

    func reshuffle() {
        shuffleSalt += 1
        scheduleSave()
    }

    func indexOfStable(_ stableID: String) -> Int? {
        visibleVideos.firstIndex { $0.stableID == stableID }
    }

    // MARK: - 收藏

    func isFavorite(_ stableID: String) -> Bool { favorites.contains(stableID) }

    func toggleFavorite(_ stableID: String) {
        if favorites.contains(stableID) {
            favorites.remove(stableID)
        } else {
            favorites.insert(stableID)
        }
        scheduleSave()
    }

    // MARK: - 观看进度

    func savePosition(_ seconds: Double, for stableID: String) {
        guard seconds > 2 else { return }
        resumePositions[stableID] = seconds
        scheduleSave()
    }

    func position(for stableID: String) -> Double? { resumePositions[stableID] }

    func clearPosition(_ stableID: String) {
        resumePositions.removeValue(forKey: stableID)
        scheduleSave()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: Self.saveURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        favorites = Set(snap.favorites)
        resumePositions = snap.resume
        mode = snap.mode
        filter = snap.filter
        shuffleSalt = snap.salt
        sortKey = snap.sortKey
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            self.writeToDisk()
        }
    }

    private func writeToDisk() {
        let snap = Snapshot(favorites: Array(favorites),
                            resume: resumePositions,
                            mode: mode,
                            filter: filter,
                            salt: shuffleSalt,
                            sortKey: sortKey)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: Self.saveURL, options: .atomic)
    }
}
