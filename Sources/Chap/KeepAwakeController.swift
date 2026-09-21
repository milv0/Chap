import Foundation
import IOKit.pwr_mgt

/// 화면 잠자기 방지 세션 컨트롤러.
///
/// IOKit 전원 어써션(`PreventUserIdleDisplaySleep`)으로 화면 꺼짐을 막는다.
/// 세션은 지속시간 만료 또는 수동 해제 시 어써션을 해제하고, 앱이 종료되면
/// IOKit이 프로세스 소유 어써션을 자동 해제하므로 켜둔 채 잊어도 안전하다.
/// 상태는 메모리에만 있으며 config에 저장하지 않는다. 메인 스레드 전제.
final class KeepAwakeController {
    /// 상태 변화 이벤트. 피드백(HUD·사운드)과 메뉴 갱신에 쓰인다.
    enum Event: Equatable {
        case started(presetTitle: String)
        case ended
    }

    private var assertionID = IOPMAssertionID(0)
    private var hasAssertion = false
    private var expiryTimer: Timer?

    /// 활성 세션의 종료 시각. 비활성이면 nil.
    private(set) var sessionEnd: Date?

    /// 세션 시작/해제/만료 시 호출. HUD·사운드 피드백과 메뉴 갱신용.
    var onEvent: ((Event) -> Void)?

    var isActive: Bool { hasAssertion }

    /// 프리셋으로 세션을 시작한다. 이미 활성이면 새 세션으로 교체한다.
    func activate(preset: KeepAwakePolicy.Preset) {
        releaseSession()
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Chap Keep Mac Awake" as CFString,
            &id)
        guard result == kIOReturnSuccess else {
            Log.app.error(
                "Keep Awake assertion failed: \(result, privacy: .public)")
            onEvent?(.ended)
            return
        }
        assertionID = id
        hasAssertion = true
        sessionEnd = Date().addingTimeInterval(preset.duration)
        expiryTimer = Timer.scheduledTimer(
            withTimeInterval: preset.duration, repeats: false
        ) { [weak self] _ in
            self?.deactivate()
        }
        Log.app.notice(
            "Keep Awake session started (\(Int(preset.duration / 60), privacy: .public)m)")
        onEvent?(.started(presetTitle: preset.title))
    }

    /// 세션을 종료하고 어써션을 해제한다. 비활성이면 아무 일도 하지 않는다.
    func deactivate() {
        guard hasAssertion else { return }
        releaseSession()
        Log.app.notice("Keep Awake session ended")
        onEvent?(.ended)
    }

    private func releaseSession() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
        }
        sessionEnd = nil
    }
}
