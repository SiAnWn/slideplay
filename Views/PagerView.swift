import SwiftUI

/// 全屏翻页容器：竖向分页 ScrollView + HUD + 临时进度条。播放时屏幕上没有任何控件。
struct PagerView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var engine: PlayerEngine

    var body: some View {
        let playlist = store.playlist
        ZStack {
            Color.black

            if playlist.count > 0 {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<playlist.count, id: \.self) { i in
                            if let item = playlist.item(at: i) {
                                VideoPageView(index: i, item: item)
                                    .id(i)
                                    .containerRelativeFrame([.horizontal, .vertical])
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: Binding<Int?>(
                    get: { engine.current },
                    set: { if let v = $0 { engine.setCurrent(v) } }
                ))
            } else {
                Text(store.videos.isEmpty
                     ? "这个文件夹里没有可播放的视频"
                     : "当前片单为空，可在菜单里切回「全部视频」")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
            }

            hudOverlay
            seekOverlay
        }
        .ignoresSafeArea()
    }

    // MARK: - HUD（亮度/音量/倍速/跳转的临时提示）

    @ViewBuilder private var hudOverlay: some View {
        if let hud = engine.hud {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: hud.icon)
                    Text(hud.text)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.bottom, 130)
                Spacer()
            }
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    // MARK: - 拖动进度时临时显示的进度条

    @ViewBuilder private var seekOverlay: some View {
        if let s = engine.seeking {
            VStack {
                Spacer()
                HStack {
                    Text(timecode(s.item))
                    Spacer()
                    Text(timecode(s.total))
                }
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 28)

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .frame(height: 4)
                            .foregroundStyle(.white.opacity(0.25))
                        Capsule()
                            .frame(width: max(0, g.size.width * CGFloat(s.item / max(s.total, 0.001))),
                                   height: 4)
                            .foregroundStyle(Theme.gradient)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .allowsHitTesting(false)
        }
    }

    private func timecode(_ t: Double) -> String {
        guard t.isFinite else { return "--:--" }
        let s = Int(t.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
