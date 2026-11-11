import SwiftUI
import UniformTypeIdentifiers

/// 根视图：启动时自动恢复上次激活的文件夹；管理抽屉、九宫格、文件夹选择器与隐私锁遮罩。
struct RootView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var manager: LibraryManager
    @EnvironmentObject private var engine: PlayerEngine
    @EnvironmentObject private var privacy: PrivacyManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var showPicker = false
    @State private var showGrid = false
    @State private var pickError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.videos.isEmpty {
                if manager.activeFolderName != nil {
                    emptyFolderView
                } else {
                    WelcomeView(onRefresh: { manager.scanDocuments(into: store) },
                                onPick: { showPicker = true })
                }
            } else {
                PagerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .topLeading) {
            if !store.videos.isEmpty && !engine.drawerOpen && !privacy.isLocked {
                menuButton
            }
        }
        .overlay {
            hudOverlay
        }
        .overlay {
            if engine.drawerOpen && !store.videos.isEmpty {
                drawerOverlay
            }
        }
        .fullScreenCover(isPresented: $showGrid) {
            NavigationStack {
                GridView()
            }
            .environmentObject(store)
            .environmentObject(engine)
            .preferredColorScheme(.dark)
        }
        .overlay {
            if privacy.isLocked {
                lockOverlay
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            manager.load()
            manager.prepareDocuments()
            if manager.activeURL != nil {
                manager.scan(into: store)
            } else {
                manager.scanDocuments(into: store)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            privacy.handlePhase(phase)
            if phase == .active {
                if manager.activeURL != nil {
                    manager.scan(into: store)
                } else {
                    manager.scanDocuments(into: store)
                }
            }
        }
        .onChange(of: privacy.isLocked) { _, locked in
            if locked {
                engine.isPlaying = false
                engine.drawerOpen = false
            }
        }
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    manager.addFolder(url: url)
                    manager.scan(into: store)
                    engine.current = 0
                }
            case .failure(let error):
                pickError = error.localizedDescription
            }
        }
        .alert("选择文件夹失败", isPresented: Binding(
            get: { pickError != nil },
            set: { if !$0 { pickError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(pickError ?? "")
        }
    }

    // MARK: - 左上角菜单按钮（保底入口；也可长按屏幕打开）

    private var menuButton: some View {
        Button {
            engine.drawerOpen = true
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.28), in: Circle())
        }
        .padding(.leading, 14)
        .padding(.top, 6)
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

    // MARK: - 已选文件夹但没有可识别视频

    private var emptyFolderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.7))
            Text("「\(manager.activeFolderName ?? "")」里没有可识别的视频")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
            Text("支持 MP4 / MOV / M4V。若视频在子文件夹里，请改选那个子文件夹。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 30)
            Button("重新选择文件夹") { showPicker = true }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .background(Theme.gradient, in: Capsule())
                .foregroundStyle(.white)
                .padding(.top, 8)
            Button("移除该文件夹") {
                if let id = manager.activeFolderID { manager.removeFolder(id: id) }
                store.videos = []
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - 隐私锁遮罩

    private var lockOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.85))
                Text("SlidePlay 已上锁")
                    .font(.headline)
                    .foregroundStyle(.white)
                Button("轻触解锁") {
                    privacy.authenticate()
                }
                .font(.body)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.gradient, in: Capsule())
                .foregroundStyle(.white)
                .padding(.top, 6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            privacy.authenticate()
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: privacy.isLocked)
    }

    // MARK: - 抽屉

    private var drawerOverlay: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { engine.drawerOpen = false }

            NavigationStack {
                DrawerView(
                    onPickFolder: {
                        engine.drawerOpen = false
                        showPicker = true
                    },
                    onOpenGrid: {
                        showGrid = true
                    }
                )
            }
            .frame(width: min(340, UIScreen.main.bounds.width * 0.82))
            .frame(maxHeight: .infinity)
            .background(.regularMaterial)
            .transition(.move(edge: .leading))
        }
        .animation(.spring(duration: 0.3), value: engine.drawerOpen)
    }
}
