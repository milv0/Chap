import ApplicationServices
import Cocoa
import os

/// macOS 앱을 실행하고 Accessibility API로 윈도우를 리사이즈하는 런처
enum AppLauncher {
    /// 앱을 실행하고 윈도우 크기/위치를 조정
    static func launch(_ site: Site, resizeQueue: DispatchQueue, onComplete: (() -> Void)? = nil) {
        guard let path = site.appPath, !path.isEmpty else {
            LauncherUtils.showAlert(message: "No app path configured for \"\(site.name)\".")
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            LauncherUtils.showAlert(message: "App not found at: \(path)")
            return
        }

        let bundle = Bundle(path: path)
        let bundleId = bundle?.bundleIdentifier

        guard let screen = targetScreen(for: site) else {
            Log.launcher.info("No display available — launching \(site.name, privacy: .private) without resize")
            let appURL = URL(fileURLWithPath: path)
            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { _, _ in
                onComplete?()
            }
            return
        }
        let bounds = centeredBounds(for: site, on: screen)
        let bw = site.width
        let bh = site.height

        Log.launcher.debug(
            "AppLauncher launch site=\(site.name, privacy: .private) path=\(path, privacy: .private) bundleId=\(bundleId ?? "nil", privacy: .private)")
        Log.launcher.debug(
            "AppLauncher target screen=\(screen.localizedName, privacy: .public) bounds={left:\(bounds.left), top:\(bounds.top), w:\(bw), h:\(bh)}")

        guard LauncherUtils.checkAccessibility() else {
            Log.launcher.info("Accessibility not granted — launching without resize")
            let appURL = URL(fileURLWithPath: path)
            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { _, _ in
                onComplete?()
            }
            return
        }

        let appRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleId
        }

        let appURL = URL(fileURLWithPath: path)
        let openConfig = NSWorkspace.OpenConfiguration()
        openConfig.activates = true
        let startTime = CFAbsoluteTimeGetCurrent()

        NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { app, error in
            if let error = error {
                Log.launcher.error("openApplication failed: \(error.localizedDescription, privacy: .public)")
                onComplete?()
                return
            }
            guard let app = app else {
                onComplete?()
                return
            }
            Log.launcher.debug(
                "app opened pid=\(app.processIdentifier) localizedName=\(app.localizedName ?? "?", privacy: .private)")

            let position = CGPoint(x: bounds.left, y: bounds.top)
            let size = CGSize(width: bw, height: bh)

            resizeQueue.async {
                var success = axResize(
                    pid: app.processIdentifier,
                    position: position,
                    size: size,
                    isRunning: appRunning
                )
                // 실패 시 1초 대기 후 한 번 더 시도 (느린 앱 대응)
                if !success {
                    Log.launcher.debug("first attempt failed for \(site.name, privacy: .private), retrying...")
                    usleep(1_000_000)
                    success = axResize(
                        pid: app.processIdentifier,
                        position: position,
                        size: size,
                        isRunning: true
                    )
                }
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                let result = success ? "success" : "failed"
                if success {
                    Log.launcher.debug(
                        "AX resize success for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s")
                } else {
                    Log.launcher.error(
                        "AX resize failed for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s")
                }
                ResizeLogger.log(
                    site: site.name, type: "app",
                    appState: appRunning ? "running" : "cold",
                    attempt: 1, delay: 0,
                    totalTime: elapsed, result: result,
                    windowCount: 0,
                    display: screen.localizedName,
                    size: "\(site.width)x\(site.height)")
                onComplete?()
            }
        }
    }

    // MARK: - AX API Resize

    private static func axResize(
        pid: pid_t, position: CGPoint, size: CGSize, isRunning: Bool
    ) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        let maxAttempts = isRunning ? 30 : 50
        let interval: useconds_t = isRunning ? 50_000 : 100_000

        if isRunning {
            usleep(150_000)
        }

        // 첫 포커스 윈도우에 적용한 뒤에도 계속 폴링하다가, 포커스 윈도우가 "다른"
        // 윈도우로 바뀌면 다시 중앙정렬한다. Excel 등은 시작 화면(스플래시)이 먼저
        // 포커스를 잡고, 그 뒤에 실제 문서 윈도우가 뜨기 때문에, 한 번만 적용하면
        // 엉뚱한 윈도우(시작 화면)를 리사이즈하고 끝나 "됐다 안 됐다" 하게 된다.
        var lastResized: AXUIElement?
        var quietPolls = 0
        let quietLimit = isRunning ? 8 : 12  // 동일 윈도우가 이만큼 유지되면 종료

        for _ in 0..<maxAttempts {
            var windowValue: AnyObject?
            let err = AXUIElementCopyAttributeValue(
                app, kAXFocusedWindowAttribute as CFString, &windowValue)
            if err == .success, let window = windowValue {
                // AXUIElementCopyAttributeValue 성공 시 항상 AXUIElement 타입
                let win = window as! AXUIElement
                if lastResized == nil || !CFEqual(lastResized!, win) {
                    // 새로운(또는 첫) 포커스 윈도우 → 적용
                    LauncherUtils.axApplyBounds(win, position: position, size: size)
                    lastResized = win
                    quietPolls = 0
                } else {
                    // 같은 윈도우가 계속 포커스 → 안정화된 것으로 보고 종료
                    quietPolls += 1
                    if quietPolls >= quietLimit { return true }
                }
            }
            usleep(interval)
        }
        return lastResized != nil
    }
}
