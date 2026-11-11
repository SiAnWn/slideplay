import SwiftUI
import UIKit
import AVFoundation

@main
struct SlidePlayApp: App {
    @StateObject private var store = LibraryStore()
    @StateObject private var manager = LibraryManager()
    @StateObject private var engine = PlayerEngine()
    @StateObject private var privacy = PrivacyManager()

    init() {
        // 静音键拨到静音也外放；锁屏继续播放；屏幕常亮。
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .environmentObject(store)
                .environmentObject(manager)
                .environmentObject(engine)
                .environmentObject(privacy)
                .onAppear { engine.configure(store: store) }
        }
    }
}
