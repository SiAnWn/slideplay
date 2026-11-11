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
        guard context.canEvaluatePolicy(.deviceAuthentication, error: &error) else {
            // 设备没设密码/Face ID：不阻塞使用
            isLocked = false
            return
        }
        context.evaluatePolicy(.deviceAuthentication, localizedReason: "解锁 SlidePlay") { [weak self] ok, _ in
            Task { @MainActor in
                self?.isLocked = !ok
            }
        }
    }
}
