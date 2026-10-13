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

    static func matchingWindow(pid: pid_t, title: String?) -> AXUIElement? {
        let eligible = eligibleWindows(app: LauncherUtils.axApplication(pid: pid))
        if let title, !title.isEmpty {
            let matches = eligible.filter { windowTitle($0) == title }
            if matches.count == 1 { return matches[0] }
        }
        return eligible.count == 1 ? eligible[0] : nil
    }

    static func windowTitle(_ window: AXUIElement) -> String? {
        stringAttribute(window, kAXTitleAttribute as CFString)
    }

    private static func eligibleWindows(app: AXUIElement) -> [AXUIElement] {
        LauncherUtils.axWindows(app: app).filter { window in
            AXUIElementSetMessagingTimeout(window, AXResizePolicy.messagingTimeoutSeconds)
            guard stringAttribute(window, kAXRoleAttribute as CFString) == kAXWindowRole,
                stringAttribute(window, kAXSubroleAttribute as CFString)
                    == kAXStandardWindowSubrole,
                AXIntrospection.isAttributeSettable(window, kAXPositionAttribute as CFString),
                AXIntrospection.isAttributeSettable(window, kAXSizeAttribute as CFString),
                boolAttribute(window, kAXMinimizedAttribute as CFString) != true,
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
