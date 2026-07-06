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
        let windowsBefore = chromeRunning ? axWindowList(pid: chromePid) : []

        NSLog("[Chap] Chrome launch for %@ — chromeRunning=%d, windowsBefore=%d",
              site.name, chromeRunning ? 1 : 0, windowsBefore.count)

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
                windowsBefore: windowsBefore,
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
        let maxAttempts = chromeRunning ? 80 : 60
        let interval: useconds_t = chromeRunning ? 50_000 : 100_000  // 50ms / 100ms

        for _ in 0..<maxAttempts {
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
               windows.count > windowsBefore.count {
                // 이전 목록에 없는 새 윈도우 찾기
                let newWindow = windows.first { win in
                    !windowsBefore.contains { CFEqual($0, win) }
                }
                // 새 윈도우를 못 찾으면 windows[0] fallback
                let target = newWindow ?? windows[0]
                LauncherUtils.axApplyBounds(target, position: position, size: size)
                return true
            }
            usleep(interval)
        }
        return false
    }

    private static func axWindowList(pid: pid_t) -> [AXUIElement] {
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
