import Foundation

/// 播放列表：顺序 或 固定种子的随机。
/// 随机模式下顺序一旦生成就固定，上下滑动稳定不变；
/// 只有重新切换模式或文件夹内容变化时才重新洗牌。
struct Playlist {
    enum Mode: String, Codable {
        case sequential
        case shuffled
    }

    let items: [VideoItem]
    let mode: Mode
    let seed: String

    func item(at index: Int) -> VideoItem? {
        guard index >= 0, index < items.count else { return nil }
        switch mode {
        case .sequential:
            return items[index]
        case .shuffled:
            return items[shuffledIndices[index]]
        }
    }

    var count: Int { items.count }

    /// 用种子 + 下标做确定性哈希排序（FNV-1a），跨启动结果一致。
    private var shuffledIndices: [Int] {
        items.indices.sorted { a, b in
            hash(seed, a) < hash(seed, b)
        }
    }

    private func hash(_ seed: String, _ index: Int) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        for byte in String(index).utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return h
    }
}
