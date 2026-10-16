import ApplicationServices
import Cocoa
import os

struct LayoutRestoreSummary: Equatable {
    let restored: Int
    /// 자리를 잡지 못한 앱 이름(저장 순서).
    let skippedApps: [String]
    var skipped: Int { skippedApps.count }
}

/// Layout 앱들을 뒤에서부터 열어, 가능하면 캡처 당시 앞쪽 창이 마지막에 활성화되게 복원한다.
enum LayoutRestoreService {
    private static var activeSession: Session?

    /// 지금 복원 중이면 false. 한 번에 하나만 돈다(같은 창을 두 세션이 번갈아 옮기지 않게).
    static var isRunning: Bool { activeSession != nil }

    @discardableResult
    static func restore(
        _ layout: ChapLayout,
        completion: @escaping (LayoutRestoreSummary) -> Void
    ) -> Bool {
        precondition(Thread.isMainThread)
        guard activeSession == nil else { return false }
        guard AccessibilityPermission.isTrusted else {
            completion(
                LayoutRestoreSummary(
                    restored: 0, skippedApps: layout.windows.map(\.applicationName)))
            return false
        }
        let session = Session(windows: Array(layout.windows.reversed())) { summary in
            activeSession = nil
            completion(summary)
        }
        activeSession = session
        session.start()
        return true
    }

    private final class Session {
        private let windows: [LayoutWindow]
        private let completion: (LayoutRestoreSummary) -> Void
        private let queue = DispatchQueue(
            label: "com.mingyupark.Chap.layout.restore", qos: .userInitiated)
        private var index = 0
        private var restored = 0
        private var skippedApps: [String] = []
        /// 앱 하나에 쓰는 시간 상한. 한 앱이 멈춰도 다음 앱은 열린다.
        private static let perAppTimeout: TimeInterval = 12

        init(
            windows: [LayoutWindow],
            completion: @escaping (LayoutRestoreSummary) -> Void
        ) {
            self.windows = windows
            self.completion = completion
        }

        func start() { restoreNext() }

        private func restoreNext() {
            precondition(Thread.isMainThread)
            guard windows.indices.contains(index) else {
                // 저장 순서(앞쪽 창이 먼저)로 알려 준다.
                completion(
                    LayoutRestoreSummary(restored: restored, skippedApps: skippedApps.reversed())
                )
                return
            }
            let item = windows[index]
            index += 1
            guard let screen = targetScreen(for: item) else {
                skip(item)
                return
            }
            let running = NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == item.bundleIdentifier && !$0.isTerminated
            }
            // 저장한 경로의 앱이 그대로 있으면 그 앱을, 옮겼으면 같은 번들 ID로 다시 찾는다.
            let savedURL = URL(fileURLWithPath: item.applicationPath)
            let savedPathMatches =
                FileManager.default.fileExists(atPath: item.applicationPath)
                && Bundle(path: item.applicationPath)?.bundleIdentifier == item.bundleIdentifier
            let applicationURL =
                running?.bundleURL
                ?? (savedPathMatches ? savedURL : nil)
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier)
            guard let applicationURL else {
                skip(item)
                return
            }
            let deadline = Date().addingTimeInterval(Self.perAppTimeout)
            // 실행 중인 앱도 openApplication으로 reopen 이벤트를 보낸다 (창을 다 닫은 앱이 기본 창을 만든다).
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) {
                [weak self] app, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard let app, error == nil else {
                        self.skip(item)
                        return
                    }
                    self.apply(item, to: app, on: screen, deadline: deadline)
                }
            }
        }

        private func skip(_ item: LayoutWindow) {
            skippedApps.append(item.applicationName)
            restoreNext()
        }

        private func apply(
            _ item: LayoutWindow, to app: NSRunningApplication, on screen: NSScreen,
            deadline: Date
        ) {
            app.activate(options: [])
            let visibleFrame = screen.visibleFrame
            let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
            queue.async { [weak self] in
                guard let self else { return }
                let window = self.waitForWindow(
                    pid: app.processIdentifier, title: item.windowTitle, deadline: deadline)
                var applied = false
                if let window {
                    LayoutWindowAccess.unminimize(window)
                    // 앱의 최소 크기보다 작게 저장된 창은 그 크기로 키우되 화면 안에 둔다.
                    let bounds = LayoutGeometry.bounds(
                        for: item.frame, visibleFrame: visibleFrame, primaryHeight: primaryHeight,
                        minimumSize: LauncherUtils.axGetMinimumSize(window))
                    let result = LauncherUtils.axApplyBounds(
                        window,
                        position: CGPoint(x: bounds.left, y: bounds.top),
                        size: CGSize(
                            width: bounds.right - bounds.left, height: bounds.bottom - bounds.top))
                    if result.applied {
                        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    }
                    applied = result.applied
                }
                DispatchQueue.main.async {
                    if applied {
                        self.restored += 1
                        self.restoreNext()
                    } else {
                        self.skip(item)
                    }
                }
            }
        }

        private func waitForWindow(pid: pid_t, title: String?, deadline: Date) -> AXUIElement? {
            while true {
                if let window = LayoutWindowAccess.matchingWindow(pid: pid, title: title) {
                    return window
                }
                guard Date() < deadline else { return nil }
                usleep(120_000)
            }
        }

        private func targetScreen(for item: LayoutWindow) -> NSScreen? {
            let screens = NSScreen.screens
            let candidates = screens.map {
                DisplayMatchCandidate(identifier: displayUUID(for: $0), name: $0.localizedName)
            }
            if let index = resolvedDisplayIndex(
                displayIdentifier: item.displayIdentifier, displayName: item.displayName,
                among: candidates)
            {
                return screens[index]
            }
            return cursorScreen
        }
    }
}
