import SwiftUI
import LocalAuthentication

/// 隐私锁：开启后，App 退到后台再回来需要 Face ID / 密码解锁。
@MainActor
final class PrivacyManager: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "privacyLock") }
    }
    @Published var isLocked: Bool

    init() {
        let on = UserDefaults.standard.bool(forKey: "privacyLock")
        enabled = on
        isLocked = on
    }

    func handlePhase(_ phase: ScenePhase) {
        guard enabled else {
            isLocked = false
            return
        }
        switch phase {
        case .background:
            isLocked = true
        case .active:
            if isLocked { authenticate() }
        default:
            break
        }
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?
        // iOS 上没有 .deviceAuthentication；用设备所有者认证（Face ID，失败回退密码）。
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 设备没设密码/生物识别：不阻塞使用
            isLocked = false
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁 SlidePlay") { [weak self] ok, _ in
            Task { @MainActor in
                self?.isLocked = !ok
            }
        }
    }
}
