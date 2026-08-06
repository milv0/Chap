import ApplicationServices
import Cocoa
import os

/// Chrome --app 모드로 URL을 열고 AX API로 윈도우 크기를 조정하는 런처
///
/// 모든 Chrome launch 요청은 단일 serial queue(requestCoordinator)에서 직렬 처리된다:
/// baseline capture → Process launch → poll for new window → resize.
/// 이렇게 하면 빠르게 연속 실행해도 요청-창 1:1 대응이 보장된다.
enum ChromeLauncher {
    private static let appPath = "/Applications/Google Chrome.app"
    private static let bundleID = "com.google.Chrome"
    private static let appName = "Google Chrome"

    /// 단일 request coordinator serial queue.
    /// Process launch도 이 큐 안에서 수행하여 요청-창 1:1 순서를 보장한다.
    private static let requestCoordinator = DispatchQueue(
        label: "com.mingyupark.Chap.ChromeRequestCoordinator",
        qos: .userInitiated
    )

    /// 여러 Chrome 런치가 겹칠 때 같은 새 창을 두 런치가 붙잡는 오배정을 방어적으로 막는다.
    /// requestCoordinator가 직렬화하지만, 방어적으로 유지.
    private static let claimedWindows = ClaimedWindowRegistry()

    private final class ClaimedWindowRegistry {
        private let lock = NSLock()
        private var claimed: [AXUIElement] = []

        /// candidates(새 창 후보) 중 아직 claim되지 않은 첫 창을 claim해 반환.
        /// liveWindows에 더 이상 없는(닫힌) 창은 정리해 레지스트리 무한 증가를 막는다.
        func claimFirstUnclaimed(from candidates: [AXUIElement], liveWindows: [AXUIElement])
            -> AXUIElement?
        {
            lock.lock()
            defer { lock.unlock() }
            claimed.removeAll { existing in
                !liveWindows.contains { CFEqual($0, existing) }
            }
            for window in candidates where !claimed.contains(where: { CFEqual($0, window) }) {
                claimed.append(window)
                return window
            }
            return nil
        }
    }

    /// Chrome을 --app 모드로 실행 (open -na)
    private static func runChromeApp(url: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-na", appName, "--args", "--app=\(url)"]
        try task.run()
    }

    /// 사이트를 Chrome --app 모드로 실행하고, AX API로 윈도우 리사이즈.
    ///
    static func launch(_ site: Site, onComplete: (() -> Void)? = nil) {
        guard FileManager.default.fileExists(atPath: appPath) else {
            Log.launcher.error("Google Chrome is not installed at \(appPath, privacy: .public)")
            LauncherUtils.showAlert(message: "Google Chrome is not installed.")
            onComplete?()
            return
        }

        let trimmedURL = site.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard launchURLHost(trimmedURL) != nil else {
            Log.launcher.error("Invalid URL: \(site.url, privacy: .private)")
            LauncherUtils.showAlert(
                message: "Invalid URL for \"\(site.name)\".",
                info: "URL을 확인해주세요: \(site.url)")
            onComplete?()
            return
        }

        guard let screen = targetScreen(for: site) else {
            Log.launcher.info("No display available — queueing Chrome without resize")
            requestCoordinator.async {
                do {
                    try runChromeApp(url: site.url)
                } catch {
                    Log.launcher.error(
                        "Failed to launch Chrome: \(error.localizedDescription, privacy: .public)")
                    LauncherUtils.showAlert(
                        message: "Failed to launch Chrome.", info: error.localizedDescription)
                }
                onComplete?()
            }
            return
        }
        let bounds = centeredBounds(for: site, on: screen)

        let position = CGPoint(x: bounds.left, y: bounds.top)
        let size = CGSize(
            width: bounds.right - bounds.left, height: bounds.bottom - bounds.top)
        let screenName = screen.localizedName
        let siteName = site.name
        let siteUrl = trimmedURL
        let requestedWidth = bounds.right - bounds.left
        let requestedHeight = bounds.bottom - bounds.top

        // 모든 작업을 requestCoordinator serial queue에서 직렬 처리
        let enqueuedAt = CFAbsoluteTimeGetCurrent()
        requestCoordinator.async {
            let startTime = CFAbsoluteTimeGetCurrent()
            let queueWait = startTime - enqueuedAt
            Log.launcher.info(
                "Chrome coordinator dequeued \(siteName, privacy: .private) after \(queueWait, format: .fixed(precision: 2))s"
            )

            // 1. Baseline: 실행 전 Chrome 윈도우 집합 기록
            let chromeApp = NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == bundleID
            }
            let chromeRunning = chromeApp != nil
            let chromePid = chromeApp?.processIdentifier ?? -1
            let windowsBefore: [AXUIElement] =
                chromeRunning ? captureExistingWindows(pid: chromePid) : []

            Log.launcher.info(
                "Chrome coordinator: launch for \(siteName, privacy: .private) — running=\(chromeRunning), windowsBefore=\(windowsBefore.count)"
            )

            // 2. Process launch (큐 안에서 수행)
            do {
                try runChromeApp(url: siteUrl)
            } catch {
                Log.launcher.error(
                    "Failed to launch Chrome: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    LauncherUtils.showAlert(
                        message: "Failed to launch Chrome.", info: error.localizedDescription)
                }
                onComplete?()
                return
            }

            guard AccessibilityPermission.isTrusted else {
                Log.launcher.info("Accessibility not granted — launching without resize")
                onComplete?()
                return
            }

            // 3. Poll + Resize
            let result = axResizeNewWindow(
                cachedPid: chromePid,
                windowsBefore: windowsBefore,
                position: position,
                size: size,
                chromeRunning: chromeRunning
            )
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            let resultLabel = result?.level.rawValue ?? "failed"
            let detail = result?.diagnostic ?? "no new window found"
            if let result {
                switch result.level {
                case .fullyApplied:
                    Log.launcher.notice(
                        "Chrome AX resize verified for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s"
                    )
                case .partiallyApplied:
                    Log.launcher.warning(
                        "Chrome AX resize partially applied for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                    )
                case .failed:
                    Log.launcher.error(
                        "Chrome AX resize verification failed for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                    )
                    AccessibilityPermission.notifyResizeFailure()
                }
            } else {
                Log.launcher.error(
                    "Chrome AX resize failed for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                )
                AccessibilityPermission.notifyResizeFailure()
            }
            ResizeLogger.log(
                site: siteName, type: "url",
                appState: chromeRunning ? "running" : "cold",
                attempt: 1, delay: 0,
                totalTime: processingTime,
                result: resultLabel,
                windowCount: windowsBefore.count,
                display: screenName,
                size: "\(requestedWidth)x\(requestedHeight)",
                detail: detail)
            onComplete?()
        }
    }

    // MARK: - AX API Resize

    /// 새 Chrome 창을 폴링해 찾고, 찾으면 리사이즈. AXBoundsResult를 반환 (못 찾으면 nil).
    private static func axResizeNewWindow(
        cachedPid: pid_t, windowsBefore: [AXUIElement], position: CGPoint, size: CGSize,
        chromeRunning: Bool
    ) -> AXBoundsResult? {
        let maxAttempts = chromeRunning ? 120 : 100
        // 50ms / 100ms polling gives running/cold timeouts of 6s / 10s.
        let interval: useconds_t = chromeRunning ? 50_000 : 100_000

        for _ in 0..<maxAttempts {
            let pid: pid_t
            if chromeRunning {
                pid = cachedPid
            } else {
                guard
                    let app = NSWorkspace.shared.runningApplications.first(where: {
                        $0.bundleIdentifier == bundleID
                    })
                else {
                    usleep(interval)
                    continue
                }
                pid = app.processIdentifier
            }

            // 실행 전 윈도우 집합과의 차집합으로 새 윈도우를 특정
            let windows = axWindows(pid: pid)
            let newWindows = windows.filter { win in
                !windowsBefore.contains { CFEqual($0, win) }
            }
            // 다른 런치가 이미 붙잡은 창은 건너뛰고, claim에 성공한 새 창만 리사이즈
            if let newWindow = claimedWindows.claimFirstUnclaimed(
                from: newWindows, liveWindows: windows)
            {
                let boundsResult = LauncherUtils.axApplyBounds(
                    newWindow, position: position, size: size)
                Log.launcher.info(
                    "Chrome AX bounds applied: level=\(boundsResult.level.rawValue, privacy: .public) pos=\(boundsResult.positionWithinTolerance) size=\(boundsResult.sizeWithinTolerance)"
                )
                return boundsResult
            }
            usleep(interval)
        }
        return nil
    }

    private static func axWindows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var windowsValue: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            app, kAXWindowsAttribute as CFString, &windowsValue)
        if err == .success, let windows = windowsValue as? [AXUIElement] {
            return windows
        }
        return []
    }

    /// 실행 전 Chrome 창 목록 스냅샷. 짧게 재시도해 실제 창 집합을 확보한다.
    private static func captureExistingWindows(pid: pid_t) -> [AXUIElement] {
        for attempt in 0..<5 {
            let windows = axWindows(pid: pid)
            if !windows.isEmpty { return windows }
            if attempt < 4 { usleep(30_000) }
        }
        return []
    }
}
