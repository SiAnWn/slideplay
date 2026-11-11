import SwiftUI
import AVFoundation

/// 单个视频页：自己持有 AVPlayer，负责起播、首帧缩略图、进度保存、自动下一个。
/// 只有"当前页"播放，其余页暂停；滑走时保存进度，滑回时从断点续播。
struct VideoPageView: View {
    let index: Int
    let item: VideoItem

    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var engine: PlayerEngine

    @State private var player: AVPlayer?
    @State private var thumbnail: UIImage?
    @State private var ready = false

    @State private var statusObs: NSKeyValueObservation?
    @State private var itemStatusObs: NSKeyValueObservation?
    @State private var timeObs: Any?
    @State private var endNotif: NSObjectProtocol?

    private var isCurrent: Bool { engine.current == index }

    var body: some View {
        ZStack {
            Color.black

            if let thumbnail {
                if engine.aspect == .fill {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 30)
                        .overlay(Color.black.opacity(0.35))
                }
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: engine.aspect == .fit ? .fit : .fill)
                    .opacity(ready ? 0 : 1)
            }

            if let player {
                AVPlayerSurfaceView(player: player, gravity: engine.aspect.videoGravity)
                    .opacity(ready ? 1 : 0)
            }

            PageGestureLayer(player: player, item: item, index: index)
        }
        .clipped()
        .animation(.easeOut(duration: 0.2), value: ready)
        .onAppear { setup() }
        .onDisappear { teardown() }
        .onChange(of: isCurrent) { _, nowCurrent in
            if nowCurrent {
                resume()
            } else {
                savePosition()
                player?.pause()
            }
        }
        .onChange(of: engine.isPlaying) { _, play in
            guard isCurrent, let player else { return }
            if play {
                player.playImmediately(atRate: Float(engine.effectiveRate))
            } else {
                player.pause()
            }
        }
        .onChange(of: engine.effectiveRate) { _, r in
            guard isCurrent, let player, player.rate != 0 else { return }
            player.rate = Float(r)
        }
        .onChange(of: engine.remoteSeek) { _, req in
            guard isCurrent, let player, let req else { return }
            let cur = CMTimeGetSeconds(player.currentTime())
            guard cur.isFinite else { return }
            let t = max(0, cur + req.seconds)
            player.seek(to: CMTime(seconds: t, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    // MARK: - 生命周期

    private func setup() {
        let avItem = AVPlayerItem(url: item.url)
        let p = AVPlayer(playerItem: avItem)
        p.automaticallyWaitsToMinimizeStalling = false
        player = p

        loadThumbnail(avItem)
        observe(avItem, player: p)

        if isCurrent { resume() }
    }

    private func teardown() {
        savePosition()
        statusObs?.invalidate(); statusObs = nil
        itemStatusObs?.invalidate(); itemStatusObs = nil
        if let timeObs { player?.removeTimeObserver(timeObs) }
        if let endNotif { NotificationCenter.default.removeObserver(endNotif) }
        player?.pause()
        player = nil
        ready = false
    }

    private func resume() {
        guard let player else { return }
        engine.isPlaying = true
        if let pos = store.position(for: item.stableID), pos > 2 {
            player.seek(to: CMTime(seconds: pos, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.playImmediately(atRate: Float(engine.effectiveRate))
        engine.updateNowPlaying()
    }

    // MARK: - 首帧缩略图

    private func loadThumbnail(_ avItem: AVPlayerItem) {
        let gen = AVAssetImageGenerator(asset: avItem.asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 720, height: 1280)
        let stableID = item.stableID
        Task {
            let start = store.position(for: stableID) ?? 0
            let time = CMTime(seconds: start + 0.5, preferredTimescale: 600)
            if let cg = try? await gen.image(at: time).image {
                await MainActor.run { self.thumbnail = UIImage(cgImage: cg) }
            }
        }
    }

    // MARK: - 观察（转义闭包只捕获引用类型，不捕获 struct self）

    private func observe(_ avItem: AVPlayerItem, player p: AVPlayer) {
        let title = item.title

        statusObs = p.observe(\.status, options: [.initial, .new]) { pl, _ in
            Task { @MainActor in
                if pl.status == .failed {
                    engine.showHUD(icon: "exclamationmark.triangle.fill", text: "打开失败：\(title)")
                }
            }
        }
        itemStatusObs = avItem.observe(\.status, options: [.initial, .new]) { it, _ in
            Task { @MainActor in
                if it.status == .readyToPlay {
                    self.ready = true
                } else if it.status == .failed {
                    engine.showHUD(icon: "exclamationmark.triangle.fill",
                                   text: "无法播放：\(title)（格式不支持或文件损坏）")
                }
            }
        }

        let store = self.store
        let engine = self.engine
        let stableID = item.stableID
        let idx = index

        timeObs = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                                            queue: .main) { t in
            guard engine.current == idx else { return }
            let sec = CMTimeGetSeconds(t)
            guard sec.isFinite, sec > 0 else { return }
            store.savePosition(sec, for: stableID)
            let dur = CMTimeGetSeconds(avItem.duration)
            if dur.isFinite, dur > 1, dur - sec < 0.4 {
                onEnded(player: p, avItem: avItem)
            }
        }

        endNotif = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: avItem, queue: .main) { _ in
            guard engine.current == idx else { return }
            onEnded(player: p, avItem: avItem)
        }
    }

    private func onEnded(player p: AVPlayer, avItem: AVPlayerItem) {
        switch engine.loopMode {
        case .single:
            p.seek(to: .zero)
            p.playImmediately(atRate: Float(engine.effectiveRate))
        case .off, .all:
            store.clearPosition(item.stableID)
            if engine.autoAdvance {
                engine.next()
            } else {
                engine.isPlaying = false
            }
        }
    }

    private func savePosition() {
        guard let player else { return }
        let sec = CMTimeGetSeconds(player.currentTime())
        if sec.isFinite { store.savePosition(sec, for: item.stableID) }
    }
}
