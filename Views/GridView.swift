import SwiftUI
import AVFoundation

/// 缩略图缓存：内存缓存 + 并发去重，网格快速滚动不重复解码。
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 400
    }

    func image(for url: URL) async -> UIImage? {
        let key = url.path as NSString
        if let hit = cache.object(forKey: key) { return hit }
        if let task = inflight[url.path] { return await task.value }

        let task = Task<UIImage?, Never> {
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 300, height: 533)
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            guard let cg = try? await gen.image(at: time).image else { return nil }
            return UIImage(cgImage: cg)
        }
        inflight[url.path] = task
        let image = await task.value
        inflight[url.path] = nil
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }
}

struct ThumbnailView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.gray.opacity(0.18)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film")
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .clipped()
        .task(id: url) {
            image = await ThumbnailCache.shared.image(for: url)
        }
    }
}

/// 九宫格选片：缩略图网格，点任意一个直接跳过去播放。
struct GridView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var engine: PlayerEngine
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 2)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(store.visibleVideos) { video in
                        cell(video)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 20)
            }
            .background(Color.black)
            .navigationTitle("选片 · \(store.visibleVideos.count) 个")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func cell(_ video: VideoItem) -> some View {
        ThumbnailView(url: video.url)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                Text(video.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.45))
            }
            .overlay(alignment: .topTrailing) {
                if store.isFavorite(video.stableID) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.heart)
                        .shadow(radius: 2)
                        .padding(5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                if let index = store.indexOfStable(video.stableID) {
                    engine.jump(to: index)
                }
                dismiss()
            }
    }
}
