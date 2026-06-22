import ApplicationServices
import Cocoa

/// Chrome --app 모드로 URL을 열고 AX API로 윈도우 크기를 조정하는 런처
enum ChromeLauncher {
    /// 사이트를 Chrome --app 모드로 실행하고, AX API로 윈도우 리사이즈
    static func launch(_ site: Site, resizeQueue: DispatchQueue, onComplete: (() -> Void)? = nil) {
        guard FileManager.default.fileExists(atPath: "/Applications/Google Chrome.app") else {
            LauncherUtils.showAlert(message: "Google Chrome is not installed.")
            onComplete?()
            return
        }

        let rawDomain = URL(string: site.url)?.host ?? ""
        guard isValidDomain(rawDomain) else {
            NSLog("[Chap] Invalid domain: %@", rawDomain)
            onComplete?()
            return
        }

        let screen = targetScreen(for: site)
        let bounds = centeredBounds(for: site, on: screen)

        // Accessibility 권한 확인
        let canResize = LauncherUtils.checkAccessibility()

        // Chrome pid 캐싱 + 윈도우 수 기록
        let chromeApp = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == "com.google.Chrome"
        }
        let chromeRunning = chromeApp != nil
        let chromePid = chromeApp?.processIdentifier ?? -1
        let windowCountBefore = chromeRunning ? axWindowCount(pid: chromePid) : 0

        NSLog("[Chap] Chrome launch for %@ — chromeRunning=%d, windowsBefore=%d",
              site.name, chromeRunning ? 1 : 0, windowCountBefore)

        // Chrome --app 모드로 실행
        let openTask = Process()
        openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openTask.arguments = ["-na", "Google Chrome", "--args", "--app=\(site.url)"]
        do {
            try openTask.run()
        } catch {
            LauncherUtils.showAlert(
                message: "Failed to launch Chrome.", info: error.localizedDescription)
            onComplete?()
            return
        }

        guard canResize else {
            NSLog("[Chap] Accessibility not granted — launching without resize")
            onComplete?()
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let position = CGPoint(x: bounds.left, y: bounds.top)
        let size = CGSize(width: bounds.right - bounds.left, height: bounds.bottom - bounds.top)

        resizeQueue.async {
            let success = axResizeNewWindow(
                cachedPid: chromePid,
                windowCountBefore: windowCountBefore,
                position: position,
                size: size,
                chromeRunning: chromeRunning
            )
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let result = success ? "success" : "failed"
            NSLog("[Chap] Chrome AX resize %@ for %@ — total %.2fs", result, site.name, elapsed)
            ResizeLogger.log(
                site: site.name, type: "url",
                appState: chromeRunning ? "running" : "cold",
                attempt: 1, delay: 0,
                totalTime: elapsed, result: result,
                windowCount: windowCountBefore,
                display: screen.localizedName,
                size: "\(site.width)x\(site.height)")
            onComplete?()
        }
    }

    // MARK: - AX API Resize

    private static func axResizeNewWindow(
        cachedPid: pid_t, windowCountBefore: Int, position: CGPoint, size: CGSize,
        chromeRunning: Bool
    ) -> Bool {
        let maxAttempts = chromeRunning ? 40 : 60
        let interval: useconds_t = chromeRunning ? 50_000 : 100_000  // 50ms / 100ms

        for _ in 0..<maxAttempts {
            // running이면 캐싱된 pid 사용, cold면 재조회
            let pid: pid_t
            if chromeRunning {
                pid = cachedPid
            } else {
                guard let app = NSWorkspace.shared.runningApplications.first(where: {
                    $0.bundleIdentifier == "com.google.Chrome"
                }) else {
                    usleep(interval)
                    continue
                }
                pid = app.processIdentifier
            }

            let app = AXUIElementCreateApplication(pid)
            var windowsValue: AnyObject?
            let err = AXUIElementCopyAttributeValue(
                app, kAXWindowsAttribute as CFString, &windowsValue)

            if err == .success, let windows = windowsValue as? [AXUIElement],
               windows.count > windowCountBefore {
                let win = windows[0]
                LauncherUtils.axApplyBounds(win, position: position, size: size)
                return true
            }
            usleep(interval)
        }
        return false
    }

    private static func axWindowCount(pid: pid_t) -> Int {
        let app = AXUIElementCreateApplication(pid)
        var windowsValue: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            app, kAXWindowsAttribute as CFString, &windowsValue)
        if err == .success, let windows = windowsValue as? [AXUIElement] {
            return windows.count
        }
        return 0
    }
}
