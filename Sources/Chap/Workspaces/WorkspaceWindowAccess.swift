import ApplicationServices
import Cocoa

/// Workspace가 캡처·복원할 수 있는 표준 앱 창을 추측 없이 고른다.
enum WorkspaceWindowAccess {
    static func representativeWindow(pid: pid_t) -> AXUIElement? {
        let app = LauncherUtils.axApplication(pid: pid)
        let eligible = eligibleWindows(app: app)
        if let focused = focusedWindow(app: app), eligible.contains(where: { CFEqual($0, focused) })
        {
            return focused
        }
        return eligible.count == 1 ? eligible[0] : nil
    }

    /// 복원할 창. 저장한 제목과 정확히 하나가 맞으면 그 창, 아니면 표준 창이 하나뿐일 때 그 창,
    /// 그것도 아니면 포커스된 표준 창(캡처 때 대표 창을 고른 규칙과 같다). 최소화된 창도 후보에 넣는다.
    static func matchingWindow(pid: pid_t, title: String?) -> AXUIElement? {
        let app = LauncherUtils.axApplication(pid: pid)
        let eligible = eligibleWindows(app: app, includeMinimized: true)
        if let title, !title.isEmpty {
            let matches = eligible.filter { windowTitle($0) == title }
            if matches.count == 1 { return matches[0] }
        }
        if eligible.count == 1 { return eligible[0] }
        if let focused = focusedWindow(app: app), eligible.contains(where: { CFEqual($0, focused) })
        {
            return focused
        }
        return nil
    }

    /// 최소화된 창을 Dock에서 꺼낸다. 실패해도 bounds 적용은 시도한다.
    static func unminimize(_ window: AXUIElement) {
        guard boolAttribute(window, kAXMinimizedAttribute as CFString) == true else { return }
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        usleep(150_000)
    }

    static func windowTitle(_ window: AXUIElement) -> String? {
        stringAttribute(window, kAXTitleAttribute as CFString)
    }

    private static func eligibleWindows(
        app: AXUIElement, includeMinimized: Bool = false
    ) -> [AXUIElement] {
        LauncherUtils.axWindows(app: app).filter { window in
            AXUIElementSetMessagingTimeout(window, AXResizePolicy.messagingTimeoutSeconds)
            guard stringAttribute(window, kAXRoleAttribute as CFString) == kAXWindowRole,
                stringAttribute(window, kAXSubroleAttribute as CFString)
                    == kAXStandardWindowSubrole,
                AXIntrospection.isAttributeSettable(window, kAXPositionAttribute as CFString),
                AXIntrospection.isAttributeSettable(window, kAXSizeAttribute as CFString),
                includeMinimized
                    || boolAttribute(window, kAXMinimizedAttribute as CFString) != true,
                boolAttribute(window, "AXFullScreen" as CFString) != true,
                let size = LauncherUtils.axGetSize(window), size.width >= 100, size.height >= 100
            else { return false }
            return true
        }
    }

    private static func focusedWindow(app: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        guard
            AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
                == .success,
            let value
        else { return nil }
        return AXIntrospection.element(from: value)
    }

    private static func stringAttribute(
        _ element: AXUIElement, _ attribute: CFString
    ) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let text = value as? String, !text.isEmpty
        else { return nil }
        return text
    }

    private static func boolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? Bool
    }
}
