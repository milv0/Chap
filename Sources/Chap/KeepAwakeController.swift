import AppKit
import IOKit.pwr_mgt

/// 화면 잠자기 방지 세션 컨트롤러.
///
/// IOKit 전원 어써션(`PreventUserIdleDisplaySleep`)으로 화면 꺼짐을 막는다.
/// 세션은 지속시간 만료 또는 수동 해제 시 어써션을 해제하고, 앱이 종료되면
/// IOKit이 프로세스 소유 어써션을 자동 해제하므로 켜둔 채 잊어도 안전하다.
/// 상태는 메모리에만 있으며 config에 저장하지 않는다. 메인 스레드 전제.
///
/// 만료는 벽시계(wall clock) 기준이다. 뚜껑을 닫아 시스템이 잠들면 `Timer`는
/// 멈춰 있다가 깨어난 뒤 남은 "깨어 있는 시간"만큼 더 기다리므로, 다음 날
/// 열어도 세션과 파란 상태 아이콘이 남는 문제가 있었다. 잠든 시간도 세는
/// `wallDeadline` 타이머와 wake 알림 재확인으로 이미 지난 세션을 즉시 정리한다.
final class KeepAwakeController {
    /// 상태 변화 이벤트. 피드백(HUD·사운드)과 메뉴 갱신에 쓰인다.
    enum Event: Equatable {
        case started(presetTitle: String)
        case ended
        /// 잠든 사이 만료되어 깨어난 뒤 정리된 세션. 사운드·HUD 없이 상태만 되돌린다.
        case expiredWhileAsleep
    }

    private var assertionID = IOPMAssertionID(0)
    private var hasAssertion = false
    private var expiryTimer: DispatchSourceTimer?
    private var wakeObservers: [NSObjectProtocol] = []

    /// 활성 세션의 종료 시각. 비활성이면 nil.
    private(set) var sessionEnd: Date?

    /// 세션 시작/해제/만료 시 호출. HUD·사운드 피드백과 메뉴 갱신용.
    var onEvent: ((Event) -> Void)?

    var isActive: Bool { hasAssertion }

    init() {
        let center = NSWorkspace.shared.notificationCenter
        wakeObservers = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
        ].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.expireIfNeeded()
            }
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        wakeObservers.forEach { center.removeObserver($0) }
        expiryTimer?.cancel()
    }

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
        scheduleExpiry(after: preset.duration)
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

    /// 벽시계 기준으로 이미 지난 세션을 정리한다. 잠자기에서 깨어날 때와
    /// 메뉴가 열릴 때 호출되며, 아직 남은 세션은 건드리지 않는다.
    func expireIfNeeded(now: Date = Date()) {
        guard hasAssertion, let end = sessionEnd,
            KeepAwakePolicy.isExpired(sessionEnd: end, now: now)
        else { return }
        let late = KeepAwakePolicy.isLateExpiry(sessionEnd: end, now: now)
        releaseSession()
        Log.app.notice(
            "Keep Awake session expired\(late ? " while asleep" : "", privacy: .public)")
        onEvent?(late ? .expiredWhileAsleep : .ended)
    }

    private func scheduleExpiry(after interval: TimeInterval) {
        expiryTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // wallDeadline은 시스템이 잠든 시간도 센다. 깨어났을 때 이미 지났으면 곧바로 실행된다.
        timer.schedule(wallDeadline: .now() + max(0, interval), leeway: .seconds(1))
        timer.setEventHandler { [weak self] in self?.handleExpiryTimer() }
        timer.resume()
        expiryTimer = timer
    }

    /// 타이머가 예정보다 이르게 울렸으면(시스템 시계 변경 등) 남은 시간으로 다시 건다.
    private func handleExpiryTimer() {
        guard hasAssertion, let end = sessionEnd else { return }
        if KeepAwakePolicy.isExpired(sessionEnd: end, now: Date()) {
            expireIfNeeded()
        } else {
            scheduleExpiry(after: end.timeIntervalSinceNow)
        }
    }

    private func releaseSession() {
        expiryTimer?.cancel()
        expiryTimer = nil
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
        }
        sessionEnd = nil
    }
}
