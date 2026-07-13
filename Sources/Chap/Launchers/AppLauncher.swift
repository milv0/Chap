import ApplicationServices
import Cocoa
import os

/// macOS 앱을 실행하고 Accessibility API로 윈도우를 리사이즈하는 런처
enum AppLauncher {
    /// 앱을 실행하고 윈도우 크기/위치를 조정
    static func launch(_ site: Site, onComplete: (() -> Void)? = nil) {
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

            // 공유 resizeQueue 대신 전용 백그라운드 큐 사용 — 콜드 스타트는 폴링이
            // 길어질 수 있어(최대 15s) 다른 런처(Chrome 등)의 리사이즈를 막지 않도록 함.
            DispatchQueue.global(qos: .userInitiated).async {
                let success = axResize(
                    pid: app.processIdentifier,
                    position: position,
                    size: size,
                    isRunning: appRunning
                )
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

    /// 앱의 현재 포커스 윈도우 중 "표준 윈도우"(문서 창)만 반환.
    /// 팔레트/다이얼로그/시트 등은 제외해 엉뚱한 보조 창을 리사이즈하지 않는다.
    private static func focusedStandardWindow(_ app: AXUIElement) -> AXUIElement? {
        var windowValue: AnyObject?
        guard
            AXUIElementCopyAttributeValue(
                app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
            let windowValue
        else { return nil }
        let win = windowValue as! AXUIElement
        var subroleValue: AnyObject?
        if AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subroleValue)
            == .success, let subrole = subroleValue as? String,
            subrole != (kAXStandardWindowSubrole as String)
        {
            return nil  // 팔레트/다이얼로그 등 → 대상 아님
        }
        return win
    }

    private static func axResize(
        pid: pid_t, position: CGPoint, size: CGSize, isRunning: Bool
    ) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        let interval: useconds_t = 120_000  // 120ms

        if isRunning {
            usleep(150_000)
        }

        // 콜드 스타트는 앱 실행 + 실제 문서 윈도우 표시까지 지연이 크므로 넉넉히 폴링한다.
        // 조기 종료하지 않는다 — 시작 화면(스플래시)이 잠시 포커스를 잡고 있다가
        // 실제 문서 윈도우가 뒤늦게 뜨는 Excel 같은 앱을 놓치지 않기 위함.
        // 포커스가 "다른" 표준 윈도우로 바뀌면 다시 중앙정렬한다. 같은 윈도우는
        // 재적용하지 않으므로 사용자가 창을 옮겨도 방해하지 않는다.
        let deadline = CFAbsoluteTimeGetCurrent() + (isRunning ? 5.0 : 15.0)
        var lastResized: AXUIElement?

        while CFAbsoluteTimeGetCurrent() < deadline {
            if let win = focusedStandardWindow(app) {
                if lastResized == nil || !CFEqual(lastResized!, win) {
                    LauncherUtils.axApplyBounds(win, position: position, size: size)
                    lastResized = win
                }
            }
            usleep(interval)
        }
        return lastResized != nil
    }
}
