import UIKit
import AVFoundation
import MediaPlayer

/// 系统亮度与音量读写。
/// 亮度用 UIScreen.main.brightness（可写，已废弃但可用）；
/// 音量用 MPVolumeView 的内部 slider（AVAudioSession.outputVolume 只读）。
enum SystemControl {
    static var brightness: Double {
        get { Double(UIScreen.main.brightness) }
        set { UIScreen.main.brightness = CGFloat(max(0, min(1, newValue))) }
    }

    private static let volumeSlider: UISlider? = {
        let mv = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 120, height: 40))
        mv.showsVolumeSlider = true
        mv.alpha = 0.01
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first {
            window.addSubview(mv)
        }
        return mv.subviews.compactMap { $0 as? UISlider }.first
    }()

    static var volume: Double {
        get { Double(AVAudioSession.sharedInstance().outputVolume) }
        set { volumeSlider?.value = Float(max(0, min(1, newValue))) }
    }
}
