import Foundation
import MediaPlayer

/// 锁屏 / 控制中心的远程命令处理。
/// iOS 上 MPRemoteCommand 只支持 target/action（@objc），不能用闭包 handler，
/// 所以用一个 NSObject 控制器承接命令，再转发给 PlayerEngine。
final class NowPlayingController: NSObject {
    private weak var engine: PlayerEngine?

    init(engine: PlayerEngine) {
        self.engine = engine
        super.init()
    }

    func start() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.isEnabled = true
        c.pauseCommand.isEnabled = true
        c.togglePlayPauseCommand.isEnabled = true
        c.nextTrackCommand.isEnabled = true
        c.previousTrackCommand.isEnabled = true
        c.skipForwardCommand.isEnabled = true
        c.skipForwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.isEnabled = true
        c.skipBackwardCommand.preferredIntervals = [15]
        c.changePlaybackRateCommand.isEnabled = true
        c.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

        c.playCommand.addTarget(self, action: #selector(play))
        c.pauseCommand.addTarget(self, action: #selector(pause))
        c.togglePlayPauseCommand.addTarget(self, action: #selector(togglePlay))
        c.nextTrackCommand.addTarget(self, action: #selector(nextTrack))
        c.previousTrackCommand.addTarget(self, action: #selector(prevTrack))
        c.skipForwardCommand.addTarget(self, action: #selector(skipForward))
        c.skipBackwardCommand.addTarget(self, action: #selector(skipBackward))
        c.changePlaybackRateCommand.addTarget(self, action: #selector(changeRate(_:)))
    }

    @objc private func play() -> MPRemoteCommandHandlerStatus {
        engine?.isPlaying = true
        return .success
    }

    @objc private func pause() -> MPRemoteCommandHandlerStatus {
        engine?.isPlaying = false
        return .success
    }

    @objc private func togglePlay() -> MPRemoteCommandHandlerStatus {
        engine?.isPlaying.toggle()
        return .success
    }

    @objc private func nextTrack() -> MPRemoteCommandHandlerStatus {
        engine?.next()
        return .success
    }

    @objc private func prevTrack() -> MPRemoteCommandHandlerStatus {
        engine?.previous()
        return .success
    }

    @objc private func skipForward() -> MPRemoteCommandHandlerStatus {
        engine?.seekByRemote(15)
        return .success
    }

    @objc private func skipBackward() -> MPRemoteCommandHandlerStatus {
        engine?.seekByRemote(-15)
        return .success
    }

    @objc private func changeRate(_ event: MPChangePlaybackRateCommandEvent) -> MPRemoteCommandHandlerStatus {
        engine?.rate = event.playbackRate
        return .success
    }
}
