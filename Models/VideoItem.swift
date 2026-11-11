import Foundation

/// 一个可播放的本地视频文件。
/// stableID 使用文件系统的 URL 资源标识（fileID），文件被移动/重命名后仍能识别，
/// 收藏与播放进度都绑定在它上面。
struct VideoItem: Identifiable, Hashable {
    let url: URL
    let stableID: String
    let title: String
    let modDate: Date
    let fileSize: Int64

    static let playableExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static func isPlayable(_ url: URL) -> Bool {
        playableExtensions.contains(url.pathExtension.lowercased())
    }

    init(url: URL, stableID: String, title: String, modDate: Date, fileSize: Int64) {
        self.url = url
        self.stableID = stableID
        self.title = title
        self.modDate = modDate
        self.fileSize = fileSize
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool { lhs.stableID == rhs.stableID }
    func hash(into hasher: inout Hasher) { hasher.combine(stableID) }
}
