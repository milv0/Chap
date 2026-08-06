import ApplicationServices
import Foundation

/// AX 요소의 메타데이터를 읽어 사람이 읽을 수 있는 형태로 요약하는 헬퍼.
///
/// 리사이즈 대상 판별(settable 검사)과 진단 로그(창 상태 스냅샷) 양쪽에서 쓰인다.
/// AX 호출 실패는 모두 "nil"/"unreadable" 같은 문자열로 강등되어 로그에 그대로 남는다.
enum AXIntrospection {
    /// AnyObject → AXUIElement 안전 캐스팅.
    static func element(from value: AnyObject) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /// AnyObject → AXValue 안전 캐스팅.
    static func value(from value: AnyObject) -> AXValue? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    /// 속성이 설정 가능한지 (에러는 false로 강등).
    static func isAttributeSettable(_ element: AXUIElement, _ attribute: CFString) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success
            && settable.boolValue
    }

    static func windowTitle(_ window: AXUIElement) -> String {
        stringAttribute(window, kAXTitleAttribute as CFString)
    }

    /// 창의 role/subrole/position/size/settable 여부 한 줄 요약 (진단 로그용).
    static func windowSummary(_ window: AXUIElement) -> String {
        let role = stringAttribute(window, kAXRoleAttribute as CFString)
        let subrole = stringAttribute(window, kAXSubroleAttribute as CFString)
        let position = pointAttribute(window, kAXPositionAttribute as CFString)
        let size = sizeAttribute(window, kAXSizeAttribute as CFString)
        let positionSettable = settableDescription(window, kAXPositionAttribute as CFString)
        let sizeSettable = settableDescription(window, kAXSizeAttribute as CFString)
        return
            "role=\(role) subrole=\(subrole) position=\(position) size=\(size) canSetPosition=\(positionSettable) canSetSize=\(sizeSettable)"
    }

    /// focused 창의 요약. 없으면 "none".
    static func focusedWindowSummary(_ app: AXUIElement) -> String {
        var value: AnyObject?
        guard
            AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
                == .success,
            let value,
            let window = element(from: value)
        else {
            return "none"
        }
        return windowSummary(window)
    }

    /// 리사이즈 대상 창을 못 찾고 끝났을 때 남길 창 상태 요약.
    ///
    /// 통합 로그의 상세 스냅샷은 보존 기간이 짧아 며칠 뒤에는 사라지므로,
    /// 원인 판별에 최소한으로 필요한 창 개수·focused 창 메타데이터는 CSV에도 남긴다.
    static func windowStateDiagnostic(app: AXUIElement) -> String {
        "windows=\(LauncherUtils.axWindows(app: app).count) focused=[\(focusedWindowSummary(app))]"
    }

    // MARK: - Private

    private static func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success, let value
        else {
            return "nil"
        }
        return String(describing: value)
    }

    private static func pointAttribute(_ element: AXUIElement, _ attribute: CFString) -> String {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            let axValue = self.value(from: value)
        else {
            return "nil"
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return "unreadable" }
        return "(\(Int(point.x)),\(Int(point.y)))"
    }

    private static func sizeAttribute(_ element: AXUIElement, _ attribute: CFString) -> String {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            let axValue = self.value(from: value)
        else {
            return "nil"
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return "unreadable" }
        return "\(Int(size.width))x\(Int(size.height))"
    }

    private static func settableDescription(_ element: AXUIElement, _ attribute: CFString)
        -> String
    {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
        guard error == .success else { return "error:\(error.rawValue)" }
        return settable.boolValue ? "true" : "false"
    }
}
