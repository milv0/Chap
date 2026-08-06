import Cocoa
import os

/// 접근성 권한 상태머신.
///
/// 권한 상태 추적, 시스템 프롬프트 요청(1회), 권한 부여 대기 임시 폴링,
/// 권한 안내 알림, 관련 노티피케이션 구독을 담당한다.
/// UI 반영(상태바 아이콘)은 `onAccessibleChanged` 콜백으로 위임한다.
final class AccessibilityStateController {
    private enum State {
        case unknown
        case granted
        case denied
    }

    private enum GrantPolling {
        static let interval: TimeInterval = 2.0
        static let duration: TimeInterval = 30.0
    }

    /// 권한 상태를 확인할 때마다 호출된다 (아이콘 갱신용).
    var onAccessibleChanged: ((Bool) -> Void)?

    /// 테스트 실행 중 시스템 프롬프트·폴링·알림을 비활성화한다.
    private let suppressesInteractivePrompts: Bool

    private var state: State = .unknown
    private var grantPollTimer: Timer?
    private var grantPollEndDate: Date?
    private var didShowAlert = false
    private var didRequestSystemPrompt = false

    init(suppressesInteractivePrompts: Bool) {
        self.suppressesInteractivePrompts = suppressesInteractivePrompts
    }

    deinit {
        grantPollTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    /// 최초 상태 확인 + 노티피케이션 구독. 앱 시작 시 한 번 호출.
    func start() {
        refresh(
            reason: "launch", showAlert: false,
            requestSystemPrompt: !suppressesInteractivePrompts)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActiveNotification),
            name: NSApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(axResizeDidFailNotification),
            name: .chapAXResizeFailed,
            object: nil)
    }

    @objc private func applicationDidBecomeActiveNotification(_ notification: Notification) {
        refresh(reason: "app active", showAlert: false)
    }

    @objc private func axResizeDidFailNotification(_ notification: Notification) {
        refresh(reason: "resize failure", showAlert: true)
    }

    func refresh(reason: String, showAlert: Bool, requestSystemPrompt: Bool = false) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.refresh(
                    reason: reason, showAlert: showAlert,
                    requestSystemPrompt: requestSystemPrompt)
            }
            return
        }

        let isTrusted = AccessibilityPermission.isTrusted
        let previousState = state
        state = isTrusted ? .granted : .denied
        onAccessibleChanged?(isTrusted)

        if isTrusted {
            stopGrantPolling()
            didShowAlert = false
            return
        }

        if requestSystemPrompt {
            requestSystemPromptIfNeeded()
            startGrantPolling(reason: "permission prompt")
        }

        let wasRevoked = previousState == .granted
        if wasRevoked {
            Log.app.error("Accessibility permission revoked from \(reason, privacy: .public)")
        }

        if wasRevoked || showAlert, !didShowAlert {
            didShowAlert = true
            showAccessibilityAlert()
        }
    }

    /// 시스템 설정의 접근성 창을 직접 연다
    func openAccessibilitySettings() {
        if let url = URL(
            string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
            startGrantPolling(reason: "accessibility settings")
        }
    }

    // MARK: - Grant polling

    /// 사용자가 시스템 설정에서 권한을 켜는 것을 잠시 동안 폴링으로 감지한다.
    private func startGrantPolling(reason: String) {
        guard !suppressesInteractivePrompts else { return }
        grantPollEndDate = Date().addingTimeInterval(GrantPolling.duration)
        guard grantPollTimer == nil else { return }

        let timer = Timer(timeInterval: GrantPolling.interval, repeats: true) {
            [weak self] _ in
            self?.pollGrant(reason: reason)
        }
        RunLoop.main.add(timer, forMode: .common)
        grantPollTimer = timer
    }

    private func pollGrant(reason: String) {
        if let endDate = grantPollEndDate, Date() > endDate {
            stopGrantPolling()
            return
        }
        refresh(reason: reason, showAlert: false)
    }

    private func stopGrantPolling() {
        grantPollTimer?.invalidate()
        grantPollTimer = nil
        grantPollEndDate = nil
    }

    // MARK: - Prompts

    private func requestSystemPromptIfNeeded() {
        guard !didRequestSystemPrompt else { return }
        didRequestSystemPrompt = true
        AccessibilityPermission.requestSystemPrompt()
    }

    /// 접근성 권한이 없을 때, 시스템 설정으로 바로 이동하는 버튼이 포함된 알림
    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            guard !AccessibilityPermission.isTrusted else {
                self.didShowAlert = false
                self.onAccessibleChanged?(true)
                return
            }
            let alert = NSAlert()
            alert.messageText = "Allow Accessibility"
            alert.informativeText = "System Settings에서 Chap을 허용해주세요."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            }
        }
    }
}
