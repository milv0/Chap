import ApplicationServices
import Cocoa

/// 런처들이 공통으로 사용하는 유틸리티
enum LauncherUtils {
    /// 에러 알림 표시 (메인 스레드에서 실행)
    static func showAlert(message: String, info: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            if let info = info { alert.informativeText = info }
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - AX API 공용

    static func axSetPosition(_ window: AXUIElement, _ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    static func axSetSize(_ window: AXUIElement, _ size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    /// 윈도우에 position/size를 안정적으로 적용 (2회 설정)
    static func axApplyBounds(_ window: AXUIElement, position: CGPoint, size: CGSize) {
        axSetPosition(window, position)
        axSetSize(window, size)
        usleep(50_000)
        axSetSize(window, size)
        axSetPosition(window, position)
    }

    // MARK: - Accessibility 권한

    private static var accessibilityPromptShown = false

    static func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted { return true }
        if !accessibilityPromptShown {
            accessibilityPromptShown = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return false
    }
}
