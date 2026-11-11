import UIKit
import AVFoundation
import Combine
import MediaPlayer

/// 用 MPVolumeView 的内部 slider 设置系统音量（outputVolume 只读）。
enum VolumeControl {
    static let slider: UISlider? = {
        let mv = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 120, height: 40))
        mv.showsVolumeSlider = true
        mv.alpha = 0.01
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first {
            window.addSubview(mv)
        }
        return mv.subviews.compactMap { $0 as? UISlider }.first
    }()
    static func set(_ value: Float) { slider?.value = value }
    static var current: Float { AVAudioSession.sharedInstance().outputVolume }
}

/// 单个视频页（UIKit）：用 AVPlayerViewController 渲染（关闭系统控件），
/// 上层盖一个透明视图承接手势。出现即播放、消失即暂停并保存进度。
final class SlidePlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    let index: Int
    let item: VideoItem
    private weak var engine: PlayerEngine?
    private weak var store: LibraryStore?

    private let player = AVPlayer()
    private var playerVC: AVPlayerViewController?
    private var playerItem: AVPlayerItem?
    private var timeObs: Any?
    private var observingStatus = false
    private var cancellables = Set<AnyCancellable>()
    private var panBase: (brightness: Double, volume: Double)?

    init(index: Int, item: VideoItem, engine: PlayerEngine, store: LibraryStore) {
        self.index = index
        self.item = item
        self.engine = engine
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayer()
        setupGestureOverlay()
        observeEngine()
    }

    // MARK: 播放器（AVPlayerViewController 渲染）

    private func setupPlayer() {
        let pi = AVPlayerItem(url: item.url)
        playerItem = pi
        player.automaticallyWaitsToMinimizeStalling = false

        let pvc = AVPlayerViewController()
        pvc.showsPlaybackControls = false
        pvc.videoGravity = (engine?.aspect ?? .fit).videoGravity
        pvc.player = player
        addChild(pvc)
        pvc.view.frame = view.bounds
        pvc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pvc.view)
        pvc.didMove(toParent: self)
        playerVC = pvc

        pi.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: nil)
        observingStatus = true
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                             object: pi, queue: .main) { [weak self] _ in
            self?.handleEnded()
        }
        timeObs = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                                                 queue: .main) { [weak self] t in
            self?.saveProgress(CMTimeGetSeconds(t))
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", (object as? AVPlayerItem)?.status == .failed {
            engine?.showHUD(icon: "exclamationmark.triangle.fill", text: "无法播放：\(item.title)")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        engine?.setCurrent(index)
        applyAspect()
        if let pos = store?.position(for: item.stableID), pos > 2 {
            player.seek(to: CMTime(seconds: pos, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.playImmediately(atRate: Float(engine?.effectiveRate ?? 1))
        engine?.isPlaying = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveProgress(CMTimeGetSeconds(player.currentTime()))
        player.pause()
    }

    private func saveProgress(_ sec: Double) {
        guard sec.isFinite, sec > 2 else { return }
        store?.savePosition(sec, for: item.stableID)
    }

    private func handleEnded() {
        guard let engine else { return }
        switch engine.loopMode {
        case .single:
            player.seek(to: .zero)
            player.playImmediately(atRate: Float(engine.effectiveRate))
        case .off, .all:
            store?.clearPosition(item.stableID)
            if engine.autoAdvance {
                engine.next()
            } else {
                player.pause()
                engine.isPlaying = false
            }
        }
    }

    // MARK: 画面比例 / 倍速（跟随引擎实时变化）

    private func applyAspect() {
        playerVC?.videoGravity = (engine?.aspect ?? .fit).videoGravity
    }

    private func observeEngine() {
        guard let engine else { return }
        engine.$aspect.dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyAspect() }
            .store(in: &cancellables)
        Publishers.CombineLatest(engine.$rate, engine.$tempRate).dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self, self.player.rate != 0 else { return }
                self.player.rate = Float(engine.effectiveRate)
            }
            .store(in: &cancellables)
    }

    // MARK: 手势（盖在播放器视图之上的透明层）

    private func setupGestureOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .clear
        view.addSubview(overlay)

        let single = UITapGestureRecognizer(target: self, action: #selector(onTap))
        let double = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))
        double.numberOfTapsRequired = 2
        single.require(toFail: double)

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        lp.minimumPressDuration = 0.35

        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self

        overlay.addGestureRecognizer(single)
        overlay.addGestureRecognizer(double)
        overlay.addGestureRecognizer(lp)
        overlay.addGestureRecognizer(pan)
    }

    @objc private func onTap() {
        guard let engine else { return }
        if engine.isPlaying {
            player.pause()
        } else {
            player.playImmediately(atRate: Float(engine.effectiveRate))
        }
        engine.isPlaying.toggle()
    }

    @objc private func onDoubleTap(_ g: UITapGestureRecognizer) {
        guard let engine else { return }
        let x = g.location(in: view).x
        let delta: Double = x < view.bounds.width / 2 ? -10 : 10
        let cur = CMTimeGetSeconds(player.currentTime())
        guard cur.isFinite else { return }
        let dur = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        var t = max(0, cur + delta)
        if dur.isFinite, dur > 0 { t = min(t, dur) }
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        engine.showHUD(icon: delta >= 0 ? "forward.fill" : "backward.fill", text: "\(Int(abs(delta))) 秒")
    }

    @objc private func onLongPress(_ g: UILongPressGestureRecognizer) {
        guard let engine else { return }
        switch g.state {
        case .began:
            engine.tempRate = 2.0
            if player.rate != 0 { player.rate = 2.0 }
            engine.showHUD(icon: "forward.fill", text: "2× 临时倍速")
        case .ended, .cancelled, .failed:
            engine.tempRate = nil
            if player.rate != 0 { player.rate = Float(engine.rate) }
        default:
            break
        }
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        guard let engine else { return }
        switch g.state {
        case .began:
            panBase = (Double(UIScreen.main.brightness), Double(VolumeControl.current))
        case .changed:
            guard let base = panBase else { return }
            let t = g.translation(in: view)
            let frac = Double(t.x) / Double(max(view.bounds.width, 1))
            let x = g.location(in: view).x
            if x < view.bounds.width / 2 {
                let v = min(1, max(0, base.brightness + frac))
                UIScreen.main.brightness = CGFloat(v)
                engine.showHUD(icon: "sun.max.fill", text: "\(Int(v * 100))%")
            } else {
                let v = min(1, max(0, base.volume + Float(frac)))
                VolumeControl.set(v)
                engine.showHUD(icon: v <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                               text: "\(Int(v * 100))%")
            }
        case .ended, .cancelled, .failed:
            panBase = nil
        default:
            break
        }
    }

    // 只让"横向为主"的拖动被本控制器的 pan 接管，竖向留给翻页
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let v = pan.velocity(in: view)
            return abs(v.x) > abs(v.y) * 1.2
        }
        return true
    }

    deinit {
        if let timeObs { player.removeTimeObserver(timeObs) }
        NotificationCenter.default.removeObserver(self)
        if observingStatus {
            playerItem?.removeObserver(self, forKeyPath: "status")
        }
    }
}
