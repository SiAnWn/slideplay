import SwiftUI
import UniformTypeIdentifiers

/// 一个被记住的外部文件夹（通过选取器授权）。
struct FolderEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var bookmark: Data
}

/// 管理视频来源：
/// 1) App 自己的 Documents 目录（主路径，无需安全权限，最可靠；配合文件共享可在"文件"App 里放视频）
/// 2) 通过选取器授权的外部文件夹（备选）
final class LibraryManager: ObservableObject {
    @Published var folders: [FolderEntry] = []
    @Published var activeFolderID: UUID?
    @Published var lastError: String?

    private(set) var activeURL: URL?

    private let foldersKey = "folderEntries"
    private let activeKey = "activeFolderID"

    var activeFolderName: String? {
        folders.first { $0.id == activeFolderID }?.name
    }

    /// App 自己的 Documents 目录（开启文件共享后，在"文件"App 里可见）。
    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 确保 Documents 目录存在，并放一个说明文件——帮助该文件夹在"文件"App 里稳定出现。
    func prepareDocuments() {
        let dir = documentsURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let hint = dir.appendingPathComponent("把视频放这里.txt")
        if !FileManager.default.fileExists(atPath: hint.path) {
            let text = "把 .mp4 / .mov / .m4v 视频文件放进这个文件夹，然后回到 SlidePlay 点『刷新视频列表』。"
            try? text.write(to: hint, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - 持久化（外部文件夹书签）

    func load() {
        if let data = UserDefaults.standard.data(forKey: foldersKey),
           let list = try? JSONDecoder().decode([FolderEntry].self, from: data) {
            folders = list
        }
        if let raw = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: raw),
           folders.contains(where: { $0.id == id }) {
            _ = activate(id: id)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: foldersKey)
        }
        UserDefaults.standard.set(activeFolderID?.uuidString, forKey: activeKey)
    }

    // MARK: - 外部文件夹管理

    func addFolder(url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        do {
            let bookmark = try url.bookmarkData(options: [],
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            let entry = FolderEntry(id: UUID(), name: url.lastPathComponent, bookmark: bookmark)
            folders.append(entry)
            activeURL = url
            activeFolderID = entry.id
            persist()
            if !granted { lastError = "没有该文件夹的访问权限" }
        } catch {
            lastError = "无法记住文件夹：\(error.localizedDescription)"
            if granted { url.stopAccessingSecurityScopedResource() }
        }
    }

    @discardableResult
    func activate(id: UUID) -> Bool {
        guard let entry = folders.first(where: { $0.id == id }) else { return false }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: entry.bookmark,
                                 options: [],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else {
            lastError = "无法打开文件夹：\(entry.name)"
            return false
        }
        activeURL = url
        activeFolderID = id
        if stale,
           let fresh = try? url.bookmarkData(options: [],
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil) {
            if let i = folders.firstIndex(where: { $0.id == id }) {
                folders[i].bookmark = fresh
            }
        }
        persist()
        return true
    }

    func removeFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        if activeFolderID == id {
            activeFolderID = folders.first?.id
            if let next = activeFolderID {
                _ = activate(id: next)
            } else {
                activeURL = nil
            }
        }
        persist()
    }

    // MARK: - 扫描

    /// 扫描 App 自己的 Documents 目录（主路径）。
    func scanDocuments(into store: LibraryStore) {
        scanFolder(documentsURL, into: store)
    }

    /// 扫描当前激活的外部文件夹（需先获取安全访问权）。
    func scan(into store: LibraryStore) {
        guard let folder = activeURL else { return }
        let started = folder.startAccessingSecurityScopedResource()
        defer { if started { folder.stopAccessingSecurityScopedResource() } }
        scanFolder(folder, into: store)
    }

    /// 共用扫描逻辑：可播放判定优先用文件真实内容类型（UTType），扩展名兜底。
    private func scanFolder(_ folder: URL, into store: LibraryStore) {
        let keys: [URLResourceKey] = [.contentModificationDateKey,
                                      .fileSizeKey,
                                      .isRegularFileKey,
                                      .contentTypeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles])) ?? []

        var items: [VideoItem] = []
        var seen = Set<String>()
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }

            let byType = values.contentType.map {
                $0.conforms(to: .movie) || $0.conforms(to: .video)
            } ?? false
            guard byType || VideoItem.isPlayable(url) else { continue }

            let stable = url.path
            guard !seen.contains(stable) else { continue }
            seen.insert(stable)
            items.append(VideoItem(url: url,
                                   stableID: stable,
                                   title: url.deletingPathExtension().lastPathComponent,
                                   modDate: values.contentModificationDate ?? .distantPast,
                                   fileSize: Int64(values.fileSize ?? 0)))
        }

        store.videos = items
    }
}
