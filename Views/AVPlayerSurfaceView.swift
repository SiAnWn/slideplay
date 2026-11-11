import SwiftUI
import AVFoundation

/// 纯渲染层：AVPlayerLayer + 指定的视频缩放模式。不接收手势，手势由父层统一管理。
struct AVPlayerSurfaceView: UIViewRepresentable {
    let player: AVPlayer
    let gravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerSurfaceUIView {
        let v = PlayerSurfaceUIView()
        v.playerLayer.videoGravity = gravity
        return v
    }

    func updateUIView(_ uiView: PlayerSurfaceUIView, context: Context) {
        uiView.playerLayer.videoGravity = gravity
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class PlayerSurfaceUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override var isUserInteractionEnabled: Bool {
        get { false }
        set { }
    }
}
