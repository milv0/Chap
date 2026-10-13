import ApplicationServices
import Cocoa
import os

struct WorkspaceRestoreSummary: Equatable {
    let restored: Int
    let skipped: Int
}

/// Workspace 앱들을 뒤에서부터 열어, 캡처 당시 앞쪽 창이 마지막에 활성화되게 복원한다.
enum WorkspaceRestoreService {
    private static var activeSession: Session?

    @discardableResult
    static func restore(
        _ workspace: ChapWorkspace,
        completion: @escaping (WorkspaceRestoreSummary) -> Void
    ) -> Bool {
        precondition(Thread.isMainThread)
        guard activeSession == nil else { return false }
        guard AccessibilityPermission.isTrusted else {
            completion(WorkspaceRestoreSummary(restored: 0, skipped: workspace.windows.count))
            return false
        }
        let session = Session(
            windows: Array(workspace.windows.reversed())
        ) { summary in
            activeSession = nil
            completion(summary)
        }
        activeSession = session
        session.start()
        return true
    }

    private final class Session {
        private let windows: [WorkspaceWindow]
        private let completion: (WorkspaceRestoreSummary) -> Void
        private let queue = DispatchQueue(
            label: "com.mingyupark.Chap.workspace.restore", qos: .userInitiated)
        private var index = 0
        private var restored = 0
        private let deadline = Date().addingTimeInterval(30)

        init(
            windows: [WorkspaceWindow],
            completion: @escaping (WorkspaceRestoreSummary) -> Void
        ) {
            self.windows = windows
            self.completion = completion
        }

        func start() { restoreNext() }

        private func restoreNext() {
            precondition(Thread.isMainThread)
            guard windows.indices.contains(index), Date() < deadline else {
                completion(
                    WorkspaceRestoreSummary(restored: restored, skipped: windows.count - restored))
                return
            }
            let item = windows[index]
            index += 1
            guard let screen = targetScreen(for: item) else {
                restoreNext()
                return
            }
            let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
            let bounds = WorkspaceGeometry.bounds(
                for: item.frame, visibleFrame: screen.visibleFrame, primaryHeight: primaryHeight)
            let running = NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == item.bundleIdentifier && !$0.isTerminated
            }
            let savedURL = URL(fileURLWithPath: item.applicationPath)
            let savedPathMatches =
                FileManager.default.fileExists(atPath: item.applicationPath)
                && Bundle(path: item.applicationPath)?.bundleIdentifier == item.bundleIdentifier
            let applicationURL =
                running?.bundleURL
                ?? (savedPathMatches ? savedURL : nil)
                ?? NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: item.bundleIdentifier)
            guard let applicationURL else {
                restoreNext()
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(
                at: applicationURL, configuration: configuration
            ) { [weak self] app, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard let app, error == nil else {
                        self.restoreNext()
                        return
                    }
                    self.apply(
                        item, to: app, bounds: bounds,
                        waitAttempts: running == nil ? 80 : 35)
                }
            }
        }

        private func apply(
            _ item: WorkspaceWindow, to app: NSRunningApplication,
            bounds: WorkspaceGeometry.Bounds, waitAttempts: Int
        ) {
            app.activate(options: [])
            queue.async { [weak self] in
                guard let self else { return }
                let window = self.waitForWindow(
                    pid: app.processIdentifier, title: item.windowTitle,
                    attempts: waitAttempts)
                let applied: Bool
                if let window {
                    let result = LauncherUtils.axApplyBounds(
                        window,
                        position: CGPoint(x: bounds.left, y: bounds.top),
                        size: CGSize(
                            width: bounds.right - bounds.left,
                            height: bounds.bottom - bounds.top))
                    if result.applied {
                        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    }
                    applied = result.applied
                } else {
                    applied = false
                }
                DispatchQueue.main.async {
                    if applied { self.restored += 1 }
                    self.restoreNext()
                }
            }
        }

        private func waitForWindow(
            pid: pid_t, title: String?, attempts: Int
        ) -> AXUIElement? {
            for attempt in 0..<attempts {
                guard Date() < deadline else { return nil }
                if let window = WorkspaceWindowAccess.matchingWindow(pid: pid, title: title) {
                    return window
                }
                if attempt < attempts - 1 { usleep(120_000) }
            }
            return nil
        }

        private func targetScreen(for item: WorkspaceWindow) -> NSScreen? {
            let screens = NSScreen.screens
            let candidates = screens.map {
                DisplayMatchCandidate(identifier: displayUUID(for: $0), name: $0.localizedName)
            }
            if let index = resolvedDisplayIndex(
                displayIdentifier: item.displayIdentifier,
                displayName: item.displayName,
                among: candidates)
            {
                return screens[index]
            }
            return cursorScreen
        }
    }
}
