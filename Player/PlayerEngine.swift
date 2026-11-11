import SwiftUI
import AVFoundation
import MediaPlayer

enum AspectMode: String, CaseIterable, Identifiable {
    case fit
    case fill
    case stretch
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fit: return "适配"
        case .fill: return "填充"
        case .stretch: return "拉伸"
        }
    }
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fit: return .resizeAspect
        case .fill: return .resizeAspectFill
        case .stretch: return .resize
        }
    }
}

enum LoopMode: String, CaseIterable, Identifiable {
    case off
    case single
    case all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "不循环"
        case .single: return "单个循环"
        case .all: return "列表循环"
        }
    }
}

/// 播放引擎：当前页、播放设置、HUD、定时停止、锁屏信息。
final class PlayerEngine: ObservableObject {
    @Published var current: Int = 0
    @Published var isPlaying: Bool = false
    @Published var rate: Float = 1.0
    @Published var tempRate: Float? = nil
    @Published var aspect: AspectMode = .fit
    @Published var loopMode: LoopMode = .off
    @Published var autoAdvance: Bool = true
    @Published var seeking: SeekInfo? = nil
    @Published var hud: HUD? = nil
    @Published var drawerOpen: Bool = false
    @Published var sleepRemaining: TimeInterval? = nil
    @Published var remoteSeek: RemoteSeek? = nil

    private(set) weak var store: LibraryStore?
    private var sleepTask: Task<Void, Never>?
    private var hudTask: Task<Void, Never>?

    struct SeekInfo: Equatable {
        let item: Double
        let total: Double
    }

    struct HUD: Equatable {
        let icon: String
        let text: String
    }

    struct RemoteSeek: Equatable {
        let nonce: TimeInterval
        let seconds: Double
    }

    func configure(store: LibraryStore) {
        self.store = store
        setupRemoteCommands()
    }

    var effectiveRate: Float { tempRate ?? rate }

    // MARK: - 锁屏 / 控制中心（iOS 用 addDefaultCommandHandler，而非 macOS 的 .handler）

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.changePlaybackRateCommand.isEnabled = true
        center.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

        _ = center.playCommand.addActionHandler { [weak self] _ in
            self?.isPlaying = true; return .success }
        _ = center.pauseCommand.addActionHandler { [weak self] _ in
            self?.isPlaying = false; return .success }
        _ = center.togglePlayPauseCommand.addActionHandler { [weak self] _ in
            self?.isPlaying.toggle(); return .success }
        _ = center.nextTrackCommand.addActionHandler { [weak self] _ in
            self?.next(); return .success }
        _ = center.previousTrackCommand.addActionHandler { [weak self] _ in
            self?.previous(); return .success }
        _ = center.skipForwardCommand.addActionHandler { [weak self] _ in
            self?.seekByRemote(15); return .success }
        _ = center.skipBackwardCommand.addActionHandler { [weak self] _ in
            self?.seekByRemote(-15); return .success }
        _ = center.changePlaybackRateCommand.addActionHandler { [weak self] event in
            if let e = event as? MPChangePlaybackRateCommandEvent { self?.rate = e.playbackRate }
            return .success }
    }

    /// 锁屏快进/快退：广播给当前页的播放器执行。
    private func seekByRemote(_ seconds: Double) {
        remoteSeek = RemoteSeek(nonce: Date().timeIntervalSince1970, seconds: seconds)
    }

    // MARK: - 切页

    func setCurrent(_ i: Int) {
        guard current != i else { return }
        current = i
        updateNowPlaying()
    }

    func next() {
        guard let store else { return }
        let count = store.playlist.count
        guard count > 0 else { return }
        if current + 1 < count {
            current += 1
        } else if loopMode == .all {
            current = 0
        }
    }

    func previous() {
        guard current > 0 else { return }
        current -= 1
    }

    func jump(to index: Int) {
        current = index
        drawerOpen = false
    }

    // MARK: - HUD

    func showHUD(icon: String, text: String) {
        hud = HUD(icon: icon, text: text)
        hudTask?.cancel()
        hudTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self, !Task.isCancelled else { return }
            self.hud = nil
        }
    }

    // MARK: - 锁屏信息

    func updateNowPlaying() {
        guard let store, let item = store.playlist.item(at: current) else { return }
        let info = MPNowPlayingInfoCenter.default()
        var dict: [String: Any] = [
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPMediaItemPropertyTitle: item.title,
        ]
        info.nowPlayingInfo = dict
    }

    // MARK: - 定时停止

    func setSleepTimer(_ seconds: TimeInterval?) {
        sleepTask?.cancel()
        sleepTask = nil
        guard let seconds else {
            sleepRemaining = nil
            return
        }
        sleepRemaining = seconds
        sleepTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.sleepRemaining = nil
                self.autoAdvance = false
                self.isPlaying = false
                self.showHUD(icon: "moon.zzz.fill", text: "定时停止，晚安")
            }
        }
    }
}
