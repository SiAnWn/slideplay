import SwiftUI
import AVFoundation

/// 纯渲染层：AVPlayerLayer + 指定的视频缩放模式。
/// blur=true 时在其上叠一层 UIVisualEffectView，对视频内容做高斯模糊（用于"模糊填充"的背景）。
/// 不接收手势，手势由父层统一管理。
struct AVPlayerSurfaceView: UIViewRepresentable {
    let player: AVPlayer
    let gravity: AVLayerVideoGravity
    var blur: Bool = false

    func makeUIView(context: Context) -> PlayerSurfaceUIView {
        let v = PlayerSurfaceUIView()
        v.playerLayer.videoGravity = gravity
        if blur { v.enableBlur() }
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

    private var blurView: UIVisualEffectView?
    func enableBlur() {
        guard blurView == nil else { return }
        let effect = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
        effect.frame = bounds
        effect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effect.isUserInteractionEnabled = false
        addSubview(effect)
        blurView = effect
    }

    override var isUserInteractionEnabled: Bool {
        get { false }
        set { }
    }
}
