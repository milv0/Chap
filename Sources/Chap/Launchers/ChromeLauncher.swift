import ApplicationServices
import Cocoa
import os

/// Chrome --app 모드로 URL을 열고 AX API로 윈도우 크기를 조정하는 런처
enum ChromeLauncher {
    private static let appPath = "/Applications/Google Chrome.app"
    private static let bundleID = "com.google.Chrome"
    private static let appName = "Google Chrome"

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
        let windowsBefore: [AXUIElement] = chromeRunning ? axWindows(pid: chromePid) : []

        Log.launcher.debug(
            "Chrome launch for \(site.name, privacy: .private) — running=\(chromeRunning), windowsBefore=\(windowsBefore.count)")

        // Chrome --app 모드로 실행
        do {
            try runChromeApp(url: site.url)
        } catch {
            Log.launcher.error("Failed to launch Chrome: \(error.localizedDescription, privacy: .public)")
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
                Log.launcher.debug(
                    "Chrome AX resize success for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s")
            } else {
                Log.launcher.error(
                    "Chrome AX resize failed for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s")
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
        let interval: useconds_t = chromeRunning ? 50_000 : 100_000  // 50ms / 100ms (running 6s / cold 10s)

        for _ in 0..<maxAttempts {
            let pid: pid_t
            if chromeRunning {
                pid = cachedPid
            } else {
                guard let app = NSWorkspace.shared.runningApplications.first(where: {
                    $0.bundleIdentifier == bundleID
                }) else {
                    usleep(interval)
                    continue
                }
                pid = app.processIdentifier
            }

            // 실행 전 윈도우 집합과의 차집합으로 새 윈도우를 특정
            // (카운트 비교는 폴링 중 사용자가 다른 윈도우를 열거나 닫으면 깨짐)
            let windows = axWindows(pid: pid)
            if let newWindow = windows.first(where: { win in
                !windowsBefore.contains { CFEqual($0, win) }
            }) {
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
}
