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

    /// pid relaunch 전후에 복원된 창을 대응시키기 위한 안정적인 메타데이터 fingerprint.
    /// AX element identity는 pid가 바뀌면 유지되지 않지만 title/role/subrole은 대체로 유지된다.
    static func windowFingerprint(_ window: AXUIElement) -> String {
        [
            stringAttribute(window, kAXTitleAttribute as CFString),
            stringAttribute(window, kAXRoleAttribute as CFString),
            stringAttribute(window, kAXSubroleAttribute as CFString),
        ].joined(separator: "|")
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

    // MARK: - Window number

    /// 세션 내에서 안정적인 창 식별자.
    ///
    /// public API인 CGWindowList에서 같은 pid·frame의 창을 찾아 실제
    /// window number를 얻는다 (Rectangle의 getWindowId에서 private
    /// `_AXUIElementGetWindow`를 제외한 public 경로와 동일). 매칭이 안 되면
    /// AX 요소의 CFHash에서 파생한 대체 id를 만든다. window number는 앱
    /// relaunch 시 window server가 새로 발급하므로 relaunch 전후 매칭에는
    /// 쓸 수 없다 — 그 용도는 `windowFingerprint`가 담당한다.
    static func windowNumber(_ window: AXUIElement) -> CGWindowID {
        var pid = pid_t(0)
        guard AXUIElementGetPid(window, &pid) == .success,
            let position = LauncherUtils.axGetPosition(window),
            let size = LauncherUtils.axGetSize(window),
            let matched = onScreenWindowNumber(
                pid: pid, frame: CGRect(origin: position, size: size))
        else {
            return derivedWindowNumber(fromElementHash: CFHash(window))
        }
        return matched
    }

    /// 파생 id는 최상위 비트를 세워 실제 window number 공간과 겹치지 않게 한다.
    /// 실제 number는 window server가 증분 발급하므로 이 영역에 도달하지 않는다.
    /// CFHash는 같은 창에 대해 조회마다 동일하고 이동·리사이즈에 영향받지 않는다.
    static func derivedWindowNumber(fromElementHash hash: CFHashCode) -> CGWindowID {
        CGWindowID(0x8000_0000) | (CGWindowID(truncatingIfNeeded: hash) & 0x7FFF_FFFF)
    }

    private static func onScreenWindowNumber(pid: pid_t, frame: CGRect) -> CGWindowID? {
        guard
            let infos = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: AnyObject]]
        else { return nil }
        for info in infos {
            guard
                let ownerPid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                ownerPid == pid,
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                bounds.equalTo(frame),
                let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
            else { continue }
            return CGWindowID(number)
        }
        return nil
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
