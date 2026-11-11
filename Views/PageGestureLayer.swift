import SwiftUI
import AVFoundation
import MediaPlayer

/// 每页上的手势层（透明分区，不显示任何 UI）：
/// - 中央：单击播放/暂停；按住 0.35s 临时 2 倍速，松手恢复
/// - 双击左/右侧：后退/前进 10 秒
/// - 左半横向拖动：亮度；右半横向拖动：音量（竖向留给翻页）
/// - 底部横向拖动：进度条（临时显示）
/// - 左边缘右滑：打开侧边菜单
struct PageGestureLayer: View {
    let player: AVPlayer?
    let item: VideoItem
    let index: Int

    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var engine: PlayerEngine

    @State private var volumeSlider: UISlider?
    @State private var volumeBase: Double?
    @State private var brightnessBase: Double?
    @State private var seekBase: Double?
    @State private var pressTask: Task<Void, Never>?
    @State private var pressStart = Date()

    private var active: Bool { engine.current == index }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 左半：亮度
                zone(w / 2, h, w / 4, h / 2)
                    .simultaneousGesture(brightnessDrag(w))
                    .gesture(doubleSeek(-10))
                // 右半：音量
                zone(w / 2, h, w * 3 / 4, h / 2)
                    .simultaneousGesture(volumeDrag(w))
                    .gesture(doubleSeek(10))
                // 中央：单击播放/暂停 + 长按 2 倍速（合并成一个手势，避免相互冲突）
                zone(w / 3, h, w / 2, h / 2)
                    .simultaneousGesture(centerGesture)
                // 底部：进度
                zone(w, 110, w / 2, h - 55)
                    .simultaneousGesture(seekDrag(w))
                    .gesture(tapToggle)
                // 左边缘：打开菜单（避开灵动岛区域）
                zone(28, h - 80, 14, h / 2 + 40)
                    .simultaneousGesture(drawerDrag)
            }
        }
        .background(
            VolumeControlHost { slider in volumeSlider = slider }
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        )
    }

    private func zone(_ w: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: w, height: h)
            .position(x: x, y: y)
    }

    // MARK: - 点按

    private var tapToggle: some Gesture {
        TapGesture().onEnded {
            guard active else { return }
            engine.isPlaying.toggle()
        }
    }

    private func doubleSeek(_ seconds: Double) -> some Gesture {
        TapGesture(count: 2)
            .onEnded { seek(by: seconds) }
            .simultaneously(with: TapGesture(count: 1).onEnded {
                guard active else { return }
                engine.isPlaying.toggle()
            })
    }

    private func seek(by delta: Double) {
        guard active, let player else { return }
        let cur = CMTimeGetSeconds(player.currentTime())
        guard cur.isFinite else { return }
        let dur = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        let t = max(0, cur + delta)
        let clamped = dur.isFinite && dur > 0 ? min(t, dur) : t
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        engine.showHUD(icon: delta >= 0 ? "forward.fill" : "backward.fill",
                       text: "\(Int(abs(delta))) 秒")
    }

    // MARK: - 中央：单击暂停 + 长按 2 倍速（用时间区分单击与长按）

    private var centerGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard active, pressTask == nil else { return }
                pressStart = Date()
                pressTask = Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard active else { return }
                        engine.tempRate = 2.0
                        engine.showHUD(icon: "forward.fill", text: "2× 临时倍速")
                    }
                }
            }
            .onEnded { value in
                pressTask?.cancel()
                pressTask = nil
                let wasLong = Date().timeIntervalSince(pressStart) >= 0.35
                let moved = abs(value.translation.width) + abs(value.translation.height) > 12
                if engine.tempRate != nil {
                    engine.tempRate = nil            // 从 2× 松手恢复
                } else if !wasLong && !moved && active {
                    engine.isPlaying.toggle()        // 轻点 = 播放/暂停
                }
            }
    }

    // MARK: - 亮度 / 音量

    private func brightnessDrag(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard active, abs(v.translation.width) > abs(v.translation.height) else { return }
                if brightnessBase == nil { brightnessBase = currentBrightness() }
                guard let base = brightnessBase else { return }
                let val = min(1, max(0, base + Double(v.translation.width / w)))
                setBrightness(val)
                engine.showHUD(icon: "sun.max.fill", text: "\(Int(val * 100))%")
            }
            .onEnded { _ in brightnessBase = nil }
    }

    private func volumeDrag(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard active, abs(v.translation.width) > abs(v.translation.height) else { return }
                if volumeBase == nil { volumeBase = Double(AVAudioSession.sharedInstance().outputVolume) }
                guard let base = volumeBase else { return }
                let val = min(1, max(0, base + Double(v.translation.width / w)))
                volumeSlider?.value = Float(val)
                engine.showHUD(icon: val == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                               text: "\(Int(val * 100))%")
            }
            .onEnded { _ in volumeBase = nil }
    }

    private var window: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
    }

    private func currentBrightness() -> Double {
        Double(window?.screen.brightness ?? 0.5)
    }

    private func setBrightness(_ value: Double) {
        window?.screen.brightness = CGFloat(value)
    }

    // MARK: - 进度

    private func seekDrag(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard active, let player,
                      abs(v.translation.width) > abs(v.translation.height) else { return }
                let dur = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
                guard dur.isFinite, dur > 1 else { return }
                if seekBase == nil { seekBase = CMTimeGetSeconds(player.currentTime()) }
                guard let base = seekBase else { return }
                let t = min(dur, max(0, base + Double(v.translation.width / w) * dur))
                engine.seeking = PlayerEngine.SeekInfo(item: t, total: dur)
            }
            .onEnded { v in
                defer { seekBase = nil; engine.seeking = nil }
                guard active, let player, let base = seekBase,
                      abs(v.translation.width) > abs(v.translation.height) else { return }
                let dur = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
                guard dur.isFinite, dur > 1 else { return }
                let t = min(dur, max(0, base + Double(v.translation.width / w) * dur))
                player.seek(to: CMTime(seconds: t, preferredTimescale: 600),
                            toleranceBefore: .zero, toleranceAfter: .zero)
                store.savePosition(t, for: item.stableID)
            }
    }

    // MARK: - 侧边菜单

    private var drawerDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard active,
                      abs(v.translation.width) > abs(v.translation.height),
                      v.translation.width > 24 else { return }
                engine.drawerOpen = true
            }
    }
}

/// 离屏挂一个 MPVolumeView，用它的内部 slider 来"设置"系统音量。
private struct VolumeControlHost: UIViewRepresentable {
    let onSlider: (UISlider?) -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        let mv = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        mv.showsVolumeSlider = true
        container.addSubview(mv)
        let slider = mv.subviews.compactMap { $0 as? UISlider }.first
        DispatchQueue.main.async { self.onSlider(slider) }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
