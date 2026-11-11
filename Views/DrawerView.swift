import SwiftUI

/// 侧边菜单：所有功能入口都在这里，播放界面保持零 UI。
struct DrawerView: View {
    let onPickFolder: () -> Void
    let onOpenGrid: () -> Void

    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var engine: PlayerEngine
    @EnvironmentObject private var manager: LibraryManager
    @EnvironmentObject private var privacy: PrivacyManager

    @State private var query = ""
    @State private var volume: Double = 0.5
    @State private var brightness: Double = 0.5

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

    private var currentItem: VideoItem? { store.playlist.item(at: engine.current) }

    private var results: [VideoItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return Array(store.visibleVideos
            .filter { $0.title.localizedCaseInsensitiveContains(q) }
            .prefix(50))
    }

    /// 修改列表相关设置后，尽量停留在当前视频。
    private func keepCurrent(_ mutate: () -> Void) {
        let stableID = currentItem?.stableID
        mutate()
        if let stableID, let index = store.indexOfStable(stableID) {
            engine.current = index
        } else {
            engine.current = 0
        }
    }

    var body: some View {
        List {
            if let cur = currentItem {
                Section("当前视频") {
                    Text(cur.title)
                        .font(.subheadline)
                        .lineLimit(2)
                    Toggle(isOn: Binding(
                        get: { store.isFavorite(cur.stableID) },
                        set: { _ in store.toggleFavorite(cur.stableID) }
                    )) {
                        Label("收藏",
                              systemImage: store.isFavorite(cur.stableID) ? "heart.fill" : "heart")
                    }
                    .tint(Theme.heart)
                }
            }

            Section("播放") {
                Picker("播放模式", selection: Binding(
                    get: { store.mode },
                    set: { newValue in keepCurrent { store.mode = newValue } }
                )) {
                    Text("顺序播放").tag(Playlist.Mode.sequential)
                    Text("随机播放").tag(Playlist.Mode.shuffled)
                }
                if store.mode == .shuffled {
                    Button("重新洗牌") {
                        keepCurrent { store.reshuffle() }
                    }
                }
                Picker("片单", selection: Binding(
                    get: { store.filter },
                    set: { newValue in keepCurrent { store.filter = newValue } }
                )) {
                    Text("全部视频").tag(LibraryStore.Filter.all)
                    Text("只看收藏").tag(LibraryStore.Filter.favoritesOnly)
                }
                Picker("倍速", selection: $engine.rate) {
                    ForEach(speeds, id: \.self) { s in
                        Text(s == 1 ? "标准" : String(format: "%.2f×", s)).tag(s)
                    }
                }
                Toggle("播完自动下一个", isOn: $engine.autoAdvance)
                Picker("循环", selection: $engine.loopMode) {
                    ForEach(LoopMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
            }

            Section("画面") {
                Picker("比例", selection: $engine.aspect) {
                    ForEach(AspectMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
            }

            Section("音量与亮度") {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: $volume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                .onChange(of: volume) { _, v in SystemControl.volume = v }

                HStack(spacing: 10) {
                    Image(systemName: "sun.min.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: $brightness, in: 0...1)
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.secondary)
                }
                .onChange(of: brightness) { _, v in SystemControl.brightness = v }
            }

            Section("排序") {
                Picker("列表排序", selection: Binding(
                    get: { store.sortKey },
                    set: { newValue in keepCurrent { store.sortKey = newValue } }
                )) {
                    ForEach(LibraryStore.SortKey.allCases) { key in
                        Text(key.label).tag(key)
                    }
                }
            }

            Section("定时停止播放") {
                HStack(spacing: 10) {
                    ForEach([15, 30, 45, 60], id: \.self) { m in
                        Button("\(m)分") { engine.setSleepTimer(TimeInterval(m * 60)) }
                            .buttonStyle(.bordered)
                    }
                    Button("关闭") { engine.setSleepTimer(nil) }
                        .buttonStyle(.bordered)
                }
                if let remaining = engine.sleepRemaining {
                    Text("将在 \(Int(remaining / 60)) 分钟后停止播放")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("快速选片") {
                Button {
                    engine.drawerOpen = false
                    onOpenGrid()
                } label: {
                    Label("九宫格浏览全部视频", systemImage: "square.grid.3x3.fill")
                }
                TextField("或搜索视频名", text: $query)
                    .textFieldStyle(.roundedBorder)
                ForEach(results) { video in
                    Button {
                        if let index = store.indexOfStable(video.stableID) {
                            engine.jump(to: index)
                        }
                    } label: {
                        HStack {
                            Text(video.title).lineLimit(1)
                            Spacer()
                            Text(video.fileSizeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if store.isFavorite(video.stableID) {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.heart)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("文件夹") {
                ForEach(manager.folders) { folder in
                    HStack {
                        Button {
                            if manager.activate(id: folder.id) {
                                manager.scan(into: store)
                                engine.current = 0
                                engine.drawerOpen = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: folder.id == manager.activeFolderID
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(folder.id == manager.activeFolderID
                                                     ? Color.accentColor : Color.secondary)
                                Text(folder.name)
                            }
                        }
                        .foregroundStyle(.primary)
                        Spacer()
                        Menu {
                            Button("移除记忆", role: .destructive) {
                                manager.removeFolder(id: folder.id)
                                if manager.activeFolderID == nil {
                                    store.videos = []
                                    engine.drawerOpen = false
                                } else {
                                    manager.scan(into: store)
                                    engine.current = 0
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                Button("添加文件夹…", action: onPickFolder)
            }

            Section("隐私") {
                Toggle(isOn: Binding(
                    get: { privacy.enabled },
                    set: { newValue in
                        privacy.enabled = newValue
                        if newValue {
                            privacy.isLocked = true
                            engine.drawerOpen = false
                        }
                    }
                )) {
                    Label("隐私锁（Face ID）", systemImage: "faceid")
                }
                Text("开启后，从后台切回需要验证面容")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("共 \(store.videos.count) 个视频 · 已收藏 \(store.favorites.count) 个 · 完全本地，无网络")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            volume = SystemControl.volume
            brightness = SystemControl.brightness
        }
        .navigationTitle("菜单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    engine.drawerOpen = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
