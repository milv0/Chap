import ApplicationServices
import Cocoa
import os

/// Chrome --app 모드로 URL을 열고 AX API로 윈도우 크기를 조정하는 런처
enum ChromeLauncher {
    private static let appPath = "/Applications/Google Chrome.app"
    private static let bundleID = "com.google.Chrome"
    private static let appName = "Google Chrome"

    /// 여러 Chrome 런치가 겹칠 때(서로 다른 URL을 빠르게 연속 실행) 같은 새 창을 두 런치가
    /// 붙잡아 서로 다른 크기로 리사이즈하는 오배정을 막는다. 이미 다른 런치가 리사이즈한 창은
    /// claim되어 다음 런치는 건너뛴다. Chrome 리사이즈는 공유 serial 큐에서 실행되어 접근이
    /// 직렬화되지만, 방어적으로 락을 둔다. (App 런처의 observationRegistry와 같은 계열의 장치.)
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

    /// 사이트를 Chrome --app 모드로 실행하고, AX API로 윈도우 리사이즈
    static func launch(_ site: Site, resizeQueue: DispatchQueue, onComplete: (() -> Void)? = nil) {
        guard FileManager.default.fileExists(atPath: appPath) else {
            Log.launcher.error("Google Chrome is not installed at \(appPath, privacy: .public)")
            LauncherUtils.showAlert(message: "Google Chrome is not installed.")
            onComplete?()
            return
        }

        let rawDomain = URL(string: site.url)?.host ?? ""
        guard isValidDomain(rawDomain) else {
            Log.launcher.error("Invalid domain: \(rawDomain, privacy: .private)")
            LauncherUtils.showAlert(
                message: "Invalid URL for \"\(site.name)\".",
                info: "URL을 확인해주세요: \(site.url)")
            onComplete?()
            return
        }

        guard let screen = targetScreen(for: site) else {
            Log.launcher.info("No display available — launching Chrome without resize")
            try? runChromeApp(url: site.url)
            onComplete?()
            return
        }
        let bounds = centeredBounds(for: site, on: screen)

        // Accessibility 권한 확인
        let canResize = LauncherUtils.checkAccessibility()

        // Chrome pid 캐싱 + 실행 전 윈도우 집합 기록
        let chromeApp = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleID
        }
        let chromeRunning = chromeApp != nil
        let chromePid = chromeApp?.processIdentifier ?? -1
        let windowsBefore: [AXUIElement] =
            chromeRunning ? captureExistingWindows(pid: chromePid) : []

        Log.launcher.info(
            "Chrome launch for \(site.name, privacy: .private) — running=\(chromeRunning), windowsBefore=\(windowsBefore.count)"
        )

        // Chrome --app 모드로 실행
        do {
            try runChromeApp(url: site.url)
        } catch {
            Log.launcher.error(
                "Failed to launch Chrome: \(error.localizedDescription, privacy: .public)")
            LauncherUtils.showAlert(
                message: "Failed to launch Chrome.", info: error.localizedDescription)
            onComplete?()
            return
        }

        guard canResize else {
            Log.launcher.info("Accessibility not granted — launching without resize")
            onComplete?()
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let position = CGPoint(x: bounds.left, y: bounds.top)
        let size = CGSize(width: bounds.right - bounds.left, height: bounds.bottom - bounds.top)

        resizeQueue.async {
            let success = axResizeNewWindow(
                cachedPid: chromePid,
                windowsBefore: windowsBefore,
                position: position,
                size: size,
                chromeRunning: chromeRunning
            )
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let result = success ? "success" : "failed"
            if success {
                Log.launcher.notice(
                    "Chrome AX resize success for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s"
                )
            } else {
                Log.launcher.error(
                    "Chrome AX resize failed for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s"
                )
            }
            ResizeLogger.log(
                site: site.name, type: "url",
                appState: chromeRunning ? "running" : "cold",
                attempt: 1, delay: 0,
                totalTime: elapsed, result: result,
                windowCount: windowsBefore.count,
                display: screen.localizedName,
                size: "\(site.width)x\(site.height)")
            onComplete?()
        }
    }

    // MARK: - AX API Resize

    private static func axResizeNewWindow(
        cachedPid: pid_t, windowsBefore: [AXUIElement], position: CGPoint, size: CGSize,
        chromeRunning: Bool
    ) -> Bool {
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
            // (카운트 비교는 폴링 중 사용자가 다른 윈도우를 열거나 닫으면 깨짐)
            let windows = axWindows(pid: pid)
            let newWindows = windows.filter { win in
                !windowsBefore.contains { CFEqual($0, win) }
            }
            // 다른 런치가 이미 붙잡은 창은 건너뛰고, claim에 성공한 새 창만 리사이즈
            if let newWindow = claimedWindows.claimFirstUnclaimed(
                from: newWindows, liveWindows: windows)
            {
                LauncherUtils.axApplyBounds(newWindow, position: position, size: size)
                return true
            }
            usleep(interval)
        }
        return false
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

    /// 실행 전 Chrome 창 목록 스냅샷. 창이 떠 있는 running 상태에서도 AX 윈도우 읽기가
    /// 순간적으로 빈 배열을 반환할 수 있는데, 이 빈 스냅샷을 기준(baseline)으로 삼으면
    /// 이후 폴링에서 잡힌 "기존" 창이 새 --app 창으로 오인돼 리사이즈된다(사용자가 보던
    /// 창이 갑자기 튐). 짧게 재시도해 실제 창 집합을 확보한다. 정말로 창이 없는 Chrome은
    /// 계속 빈 배열이므로 콜드/무창 케이스의 기존 동작을 깨지 않는다.
    private static func captureExistingWindows(pid: pid_t) -> [AXUIElement] {
        for attempt in 0..<5 {
            let windows = axWindows(pid: pid)
            if !windows.isEmpty { return windows }
            if attempt < 4 { usleep(30_000) }
        }
        return []
    }
}
