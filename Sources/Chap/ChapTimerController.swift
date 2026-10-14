import AppKit
import os

/// 카운트다운 타이머. 한 번에 하나만 돌고 상태는 메모리에만 있다. 메인 스레드 전제.
///
/// 끝나는 시각은 벽시계 기준(`wallDeadline`)이라 뚜껑을 닫아 잠든 시간도 센다.
/// 깨어나면 다시 확인해, 잠든 사이 끝났으면 깨어난 직후 알린다. Keep Mac Awake와는 따로 돈다.
final class ChapTimerController {
    /// 시작·중지·끝났을 때 보낸다. object는 끝나는 시각(Date?), 꺼졌으면 nil.
    static let didChangeNotification = Notification.Name("ChapTimerDidChange")

    enum Event: Equatable {
        case started
        case stopped
        case finished
    }

    private(set) var endDate: Date?
    /// 지금 타이머의 전체 길이(진행선용). 꺼져 있으면 nil.
    private(set) var length: TimeInterval?
    private var deadlineTimer: DispatchSourceTimer?
    private var wakeObservers: [NSObjectProtocol] = []

    /// 상태가 바뀔 때마다 불린다. 피드백(사운드·HUD)과 메뉴·노치 갱신용.
    var onEvent: (Event) -> Void = { _ in }

    var isRunning: Bool { endDate != nil }

    init() {
        let center = NSWorkspace.shared.notificationCenter
        wakeObservers = [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification]
            .map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.finishIfDue()
                }
            }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        wakeObservers.forEach { center.removeObserver($0) }
        deadlineTimer?.cancel()
    }

    /// 새 타이머를 시작한다. 돌고 있던 타이머는 바꾼다.
    func start(length: TimeInterval) {
        let length = min(
            max(length, TimerPolicy.lengthRange.lowerBound), TimerPolicy.lengthRange.upperBound)
        endDate = Date().addingTimeInterval(length)
        self.length = length
        schedule(after: length)
        Log.app.notice("Timer started (\(Int(length / 60), privacy: .public)m)")
        emit(.started)
    }

    func stop() {
        guard isRunning else { return }
        clear()
        Log.app.notice("Timer stopped")
        emit(.stopped)
    }

    /// 끝날 시각이 지났으면 끝낸다. 잠에서 깨어날 때와 메뉴를 열 때 부른다.
    func finishIfDue(now: Date = Date()) {
        guard let endDate, endDate <= now else { return }
        clear()
        Log.app.notice("Timer finished")
        emit(.finished)
    }

    private func schedule(after interval: TimeInterval) {
        deadlineTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(wallDeadline: .now() + max(0, interval), leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            guard let self, let end = self.endDate else { return }
            // 시계가 바뀌어 이르게 울렸으면 남은 시간으로 다시 건다.
            if end <= Date() {
                self.finishIfDue()
            } else {
                self.schedule(after: end.timeIntervalSinceNow)
            }
        }
        timer.resume()
        deadlineTimer = timer
    }

    private func clear() {
        deadlineTimer?.cancel()
        deadlineTimer = nil
        endDate = nil
        length = nil
    }

    private func emit(_ event: Event) {
        onEvent(event)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: endDate)
    }
}
