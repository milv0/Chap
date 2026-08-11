import ApplicationServices
import Foundation

extension Notification.Name {
    static let chapAXResizeFailed = Notification.Name("chapAXResizeFailed")
}

/// Accessibility 권한 요청은 사용자에게 onboarding UI가 보인 뒤에만 수행한다.
/// TestFlight/Mac App Store 빌드는 launch 직전의 비활성 상태에서 시스템 프롬프트가
/// 보이지 않을 수 있으므로, prompt timing을 명시적으로 분리한다.
enum AccessibilityPromptPolicy {
    static func shouldRequestAtLaunch(
        isTrusted: Bool,
        suppressesInteractivePrompts: Bool
    ) -> Bool {
        !isTrusted && !suppressesInteractivePrompts
    }

    static func shouldRequestAfterOnboarding(
        isTrusted: Bool,
        suppressesInteractivePrompts: Bool
    ) -> Bool {
        shouldRequestAtLaunch(
            isTrusted: isTrusted,
            suppressesInteractivePrompts: suppressesInteractivePrompts)
    }
}

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestSystemPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func notifyResizeFailure() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .chapAXResizeFailed, object: nil)
        }
    }
}
