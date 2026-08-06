import ApplicationServices
import Foundation

extension Notification.Name {
    static let chapAXResizeFailed = Notification.Name("chapAXResizeFailed")
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
