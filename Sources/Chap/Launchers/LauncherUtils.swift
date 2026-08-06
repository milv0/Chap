import ApplicationServices
import Cocoa

/// AX API를 통한 bounds 적용 결과 상세.
/// 각 set 호출의 에러 코드, 적용 후 읽은 실제 position/size, tolerance 기준 판정을 제공한다.
struct AXBoundsResult {
    /// tolerance (pixels) for position/size verification.
    static let defaultTolerance: CGFloat = 4.0

    /// 개별 AX set 호출 결과
    struct SetOutcome {
        let attribute: String
        let error: AXError
        var succeeded: Bool { error == .success }
    }

    /// 적용 결과 수준
    enum ApplicationLevel: String {
        case fullyApplied = "fully"
        case partiallyApplied = "partial"
        case failed = "failed"
    }

    let positionOutcome: SetOutcome
    let sizeOutcome: SetOutcome

    /// 적용 후 읽은 실제 position (읽기 실패 시 nil)
    let actualPosition: CGPoint?
    /// 적용 후 읽은 실제 size (읽기 실패 시 nil)
    let actualSize: CGSize?

    /// 요청한 position
    let requestedPosition: CGPoint
    /// 요청한 size
    let requestedSize: CGSize

    /// tolerance 기반 판정
    let level: ApplicationLevel

    /// position이 tolerance 범위 내 일치하는지
    var positionWithinTolerance: Bool {
        guard let actual = actualPosition else { return false }
        return abs(actual.x - requestedPosition.x) <= Self.defaultTolerance
            && abs(actual.y - requestedPosition.y) <= Self.defaultTolerance
    }

    /// size가 tolerance 범위 내 일치하는지
    var sizeWithinTolerance: Bool {
        guard let actual = actualSize else { return false }
        return abs(actual.width - requestedSize.width) <= Self.defaultTolerance
            && abs(actual.height - requestedSize.height) <= Self.defaultTolerance
    }

    /// 최종 성공 여부 (fully 또는 partially)
    var applied: Bool { level != .failed }

    // MARK: - Pure determination logic (TDD-testable)

    /// 순수 판정 함수: 테스트에서 AX 호출 없이 결과 판정 로직을 검증할 수 있다.
    static func determineLevel(
        positionError: AXError,
        sizeError: AXError,
        actualPosition: CGPoint?,
        actualSize: CGSize?,
        requestedPosition: CGPoint,
        requestedSize: CGSize,
        tolerance: CGFloat = defaultTolerance
    ) -> ApplicationLevel {
        let posOK: Bool

        if let actual = actualPosition {
            let dx = abs(actual.x - requestedPosition.x)
            let dy = abs(actual.y - requestedPosition.y)
            posOK = dx <= tolerance && dy <= tolerance
        } else {
            posOK = false
        }

        let sizeOK: Bool

        if let actual = actualSize {
            let dw = abs(actual.width - requestedSize.width)
            let dh = abs(actual.height - requestedSize.height)
            sizeOK = dw <= tolerance && dh <= tolerance
        } else {
            sizeOK = false
        }

        if posOK && sizeOK { return .fullyApplied }
        if posOK || sizeOK { return .partiallyApplied }
        return .failed
    }

    /// 순수 진단 요약: 어느 축이 tolerance를 벗어났는지와 요청·실제 값을 한 줄로 만든다.
    ///
    /// level만 로그에 남기면 partial/failed의 원인(앱 최소 크기 클램프인지, 위치가 밀린
    /// 것인지, 읽기 실패인지)을 사후에 구분할 수 없어 판정 근거를 함께 남긴다.
    /// CSV 한 칸으로도 쓰이므로 콤마를 포함하지 않는다.
    static func diagnosticSummary(
        positionError: AXError,
        sizeError: AXError,
        actualPosition: CGPoint?,
        actualSize: CGSize?,
        requestedPosition: CGPoint,
        requestedSize: CGSize,
        tolerance: CGFloat = defaultTolerance
    ) -> String {
        var tokens: [String] = []

        tokens.append("posReq=(\(pixels(requestedPosition.x)) \(pixels(requestedPosition.y)))")
        if let actual = actualPosition {
            let dx = abs(actual.x - requestedPosition.x)
            let dy = abs(actual.y - requestedPosition.y)
            tokens.append("posAct=(\(pixels(actual.x)) \(pixels(actual.y)))")
            tokens.append("pos=\(dx <= tolerance && dy <= tolerance ? "ok" : "off")")
        } else {
            tokens.append("posAct=unreadable")
            tokens.append("pos=unreadable")
        }

        tokens.append("sizeReq=\(pixels(requestedSize.width))x\(pixels(requestedSize.height))")
        if let actual = actualSize {
            let dw = abs(actual.width - requestedSize.width)
            let dh = abs(actual.height - requestedSize.height)
            tokens.append("sizeAct=\(pixels(actual.width))x\(pixels(actual.height))")
            tokens.append("size=\(dw <= tolerance && dh <= tolerance ? "ok" : "off")")
        } else {
            tokens.append("sizeAct=unreadable")
            tokens.append("size=unreadable")
        }

        tokens.append("posErr=\(positionError.rawValue)")
        tokens.append("sizeErr=\(sizeError.rawValue)")
        return tokens.joined(separator: " ")
    }

    private static func pixels(_ value: CGFloat) -> String {
        String(Int(value.rounded()))
    }

    /// 이 결과의 진단 요약 (통합 로그·CSV 공용).
    var diagnostic: String {
        Self.diagnosticSummary(
            positionError: positionOutcome.error,
            sizeError: sizeOutcome.error,
            actualPosition: actualPosition,
            actualSize: actualSize,
            requestedPosition: requestedPosition,
            requestedSize: requestedSize)
    }
}

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

    /// pid의 AX 윈도우 목록. 실패 시 빈 배열.
    static func axWindows(pid: pid_t) -> [AXUIElement] {
        axWindows(app: AXUIElementCreateApplication(pid))
    }

    /// AX 앱 요소의 윈도우 목록. 실패 시 빈 배열.
    static func axWindows(app: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        guard
            AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
                == .success,
            let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    /// 실행 전 앱 창 목록 스냅샷. AX 윈도우 읽기가 순간적으로 빈 배열을 반환할 수 있어
    /// 짧게 재시도해 실제 창 집합을 확보한다.
    static func captureExistingWindows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        for attempt in 0..<5 {
            let windows = axWindows(app: app)
            if !windows.isEmpty { return windows }
            if attempt < 4 { usleep(30_000) }
        }
        return []
    }

    static func axSetPosition(_ window: AXUIElement, _ point: CGPoint) -> AXError {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return .failure }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    static func axSetSize(_ window: AXUIElement, _ size: CGSize) -> AXError {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return .failure }
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    /// 윈도우의 현재 position을 읽는다.
    static func axGetPosition(_ window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            window, kAXPositionAttribute as CFString, &value)
        guard err == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    /// 윈도우의 현재 size를 읽는다.
    static func axGetSize(_ window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            window, kAXSizeAttribute as CFString, &value)
        guard err == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    /// 윈도우에 position/size를 안정적으로 적용하고 결과를 상세 반환 (2회 설정 + 읽기 검증)
    @discardableResult
    static func axApplyBounds(_ window: AXUIElement, position: CGPoint, size: CGSize)
        -> AXBoundsResult
    {
        // 1차 적용
        _ = axSetPosition(window, position)
        _ = axSetSize(window, size)
        usleep(50_000)
        // 2차 적용 (안정성)
        let sizeErr2 = axSetSize(window, size)
        let posErr2 = axSetPosition(window, position)

        // 검증을 위해 짧은 대기 후 읽기
        usleep(20_000)
        let actualPosition = axGetPosition(window)
        let actualSize = axGetSize(window)

        // 최종 에러: 2차 적용 결과 우선
        let finalPosErr = posErr2
        let finalSizeErr = sizeErr2

        let level = AXBoundsResult.determineLevel(
            positionError: finalPosErr,
            sizeError: finalSizeErr,
            actualPosition: actualPosition,
            actualSize: actualSize,
            requestedPosition: position,
            requestedSize: size
        )

        return AXBoundsResult(
            positionOutcome: .init(attribute: kAXPositionAttribute as String, error: finalPosErr),
            sizeOutcome: .init(attribute: kAXSizeAttribute as String, error: finalSizeErr),
            actualPosition: actualPosition,
            actualSize: actualSize,
            requestedPosition: position,
            requestedSize: size,
            level: level
        )
    }

}
