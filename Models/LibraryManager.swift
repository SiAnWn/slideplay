import SwiftUI
import UniformTypeIdentifiers

/// 一个被记住的文件夹。
struct FolderEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var bookmark: Data
}

/// 管理多个文件夹书签：添加、切换、移除、扫描当前激活的文件夹。
/// 注意：读取选取器授权的文件夹前，必须调用 startAccessingSecurityScopedResource()。
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

    // MARK: - 持久化

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

    // MARK: - 文件夹管理

    func addFolder(url: URL) {
        // 激活选取器授予的访问权
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

    /// 扫描当前激活文件夹内的可播放视频。
    /// 先获取安全访问权；判定可播放优先用文件真实内容类型（UTType），扩展名兜底。
    func scan(into store: LibraryStore) {
        guard let folder = activeURL else { return }
        let started = folder.startAccessingSecurityScopedResource()
        defer { if started { folder.stopAccessingSecurityScopedResource() } }

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
