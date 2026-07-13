import ApplicationServices
import Cocoa
import os

/// macOS 앱을 실행하고 Accessibility API로 윈도우를 리사이즈하는 런처
enum AppLauncher {
    /// 앱을 실행하고 윈도우 크기/위치를 조정
    static func launch(_ site: Site, onComplete: (() -> Void)? = nil) {
        guard let path = site.appPath, !path.isEmpty else {
            Log.launcher.error("No app path configured for \(site.name, privacy: .private)")
            LauncherUtils.showAlert(message: "No app path configured for \"\(site.name)\".")
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            Log.launcher.error("App not found at: \(path, privacy: .private)")
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

        Log.launcher.info(
            "AppLauncher launch site=\(site.name, privacy: .private) path=\(path, privacy: .private) bundleId=\(bundleId ?? "nil", privacy: .private)")
        Log.launcher.info(
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
            Log.launcher.info(
                "app opened pid=\(app.processIdentifier) localizedName=\(app.localizedName ?? "?", privacy: .private)")

            let position = CGPoint(x: bounds.left, y: bounds.top)
            let size = CGSize(width: bw, height: bh)

            // 공유 resizeQueue 대신 전용 백그라운드 큐 사용 — 관찰(run loop)이
            // 길게 유지될 수 있어(최대 20s) 다른 런처(Chrome 등)의 리사이즈를 막지 않도록 함.
            DispatchQueue.global(qos: .userInitiated).async {
                let latency = observeAndCenter(
                    pid: app.processIdentifier,
                    position: position,
                    size: size,
                    startTime: startTime,
                    timeout: appRunning ? 8.0 : 20.0
                )
                if let latency {
                    Log.launcher.notice(
                        "AX resize success for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s")
                } else {
                    Log.launcher.error(
                        "AX resize failed for \(site.name, privacy: .private) — \(CFAbsoluteTimeGetCurrent() - startTime, format: .fixed(precision: 2))s")
                }
                ResizeLogger.log(
                    site: site.name, type: "app",
                    appState: appRunning ? "running" : "cold",
                    attempt: 1, delay: 0,
                    totalTime: latency ?? (CFAbsoluteTimeGetCurrent() - startTime),
                    result: latency != nil ? "success" : "failed",
                    windowCount: 0,
                    display: screen.localizedName,
                    size: "\(site.width)x\(site.height)")
                onComplete?()
            }
        }
    }

    // MARK: - AX API Resize

    /// 윈도우 리사이즈 대상/상태를 AXObserver 콜백과 공유하기 위한 컨텍스트.
    /// 콜백과 초기 정렬이 모두 같은 (run loop) 스레드에서 실행되므로 별도 동기화는 불필요.
    private final class ResizeContext {
        let position: CGPoint
        let size: CGSize
        let startTime: CFAbsoluteTime
        var resized: [AXUIElement] = []
        var firstResizeLatency: TimeInterval?
        var lastResizeTime: CFAbsoluteTime?
        var didResize: Bool { !resized.isEmpty }
        init(position: CGPoint, size: CGSize, startTime: CFAbsoluteTime) {
            self.position = position
            self.size = size
            self.startTime = startTime
        }
    }

    /// 표준 윈도우(문서 창)면 아직 정렬 안 한 경우에 한해 중앙정렬한다.
    /// 팔레트/다이얼로그/시트(비표준 subrole)는 건드리지 않는다.
    private static func centerIfStandard(_ window: AXUIElement, ctx: ResizeContext) {
        var subroleValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleValue)
            == .success, let subrole = subroleValue as? String,
            subrole != (kAXStandardWindowSubrole as String)
        {
            return
        }
        if ctx.resized.contains(where: { CFEqual($0, window) }) { return }
        LauncherUtils.axApplyBounds(window, position: ctx.position, size: ctx.size)
        ctx.resized.append(window)
        let now = CFAbsoluteTimeGetCurrent()
        ctx.lastResizeTime = now
        if ctx.firstResizeLatency == nil { ctx.firstResizeLatency = now - ctx.startTime }
    }

    private static func axWindows(_ app: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        guard
            AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    /// AXObserver로 윈도우 생성(kAXWindowCreatedNotification)을 구독해, 생성되는 모든
    /// 표준 윈도우를 즉시 중앙정렬한다. Excel처럼 시작 화면 창과 문서 창이 시차를 두고
    /// 뜨는 경우에도, 폴링 예산 추측 없이 각 창이 뜨는 순간 정렬한다.
    /// timeout 동안 관찰하며, 옵저버 생성 실패 시 폴링 방식으로 폴백한다.
    private static func observeAndCenter(
        pid: pid_t, position: CGPoint, size: CGSize, startTime: CFAbsoluteTime,
        timeout: TimeInterval
    ) -> TimeInterval? {
        let app = AXUIElementCreateApplication(pid)
        let ctx = ResizeContext(position: position, size: size, startTime: startTime)

        var observer: AXObserver?
        let createErr = AXObserverCreate(
            pid,
            { _, element, _, refcon in
                guard let refcon else { return }
                let ctx = Unmanaged<ResizeContext>.fromOpaque(refcon).takeUnretainedValue()
                AppLauncher.centerIfStandard(element, ctx: ctx)
            }, &observer)

        guard createErr == .success, let observer else {
            Log.launcher.error("AXObserverCreate failed — falling back to polling")
            return axResizePolling(
                app: app, position: position, size: size, startTime: startTime, timeout: timeout)
        }

        let refcon = Unmanaged.passUnretained(ctx).toOpaque()
        AXObserverAddNotification(
            observer, app, kAXWindowCreatedNotification as CFString, refcon)

        let runLoop = CFRunLoopGetCurrent()
        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(runLoop, source, .defaultMode)

        // 이미 떠 있는 윈도우 즉시 정렬 + 주기적 재스캔(창 생성 알림 누락 보완).
        // 첫 정렬 이후에는 grace(3s) 동안 새 창이 없으면 종료한다 — 단일 창 앱(Notes 등)은
        // 곧 끝나고, Excel처럼 창이 더 뜨면 새 정렬마다 grace가 갱신되어 계속 잡는다.
        let hardDeadline = CFAbsoluteTimeGetCurrent() + timeout
        let grace: TimeInterval = 3.0
        while CFAbsoluteTimeGetCurrent() < hardDeadline {
            for win in axWindows(app) {
                centerIfStandard(win, ctx: ctx)
            }
            CFRunLoopRunInMode(.defaultMode, 0.3, false)
            if let last = ctx.lastResizeTime, CFAbsoluteTimeGetCurrent() - last >= grace {
                break
            }
        }

        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        AXObserverRemoveNotification(observer, app, kAXWindowCreatedNotification as CFString)
        return ctx.firstResizeLatency
    }

    /// AXObserver를 못 쓸 때의 폴백: 포커스된 표준 윈도우를 폴링하며 정렬.
    /// 첫 정렬까지의 지연시간(초)을 반환하고, 못 잡으면 nil.
    private static func axResizePolling(
        app: AXUIElement, position: CGPoint, size: CGSize, startTime: CFAbsoluteTime,
        timeout: TimeInterval
    ) -> TimeInterval? {
        let interval: useconds_t = 120_000
        let deadline = CFAbsoluteTimeGetCurrent() + timeout
        var lastResized: AXUIElement?
        var latency: TimeInterval?
        while CFAbsoluteTimeGetCurrent() < deadline {
            var windowValue: AnyObject?
            if AXUIElementCopyAttributeValue(
                app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
                let windowValue
            {
                let win = windowValue as! AXUIElement
                var subroleValue: AnyObject?
                let isStandard =
                    !(AXUIElementCopyAttributeValue(
                        win, kAXSubroleAttribute as CFString, &subroleValue) == .success
                        && (subroleValue as? String) != nil
                        && (subroleValue as? String) != (kAXStandardWindowSubrole as String))
                if isStandard, lastResized == nil || !CFEqual(lastResized!, win) {
                    LauncherUtils.axApplyBounds(win, position: position, size: size)
                    lastResized = win
                    if latency == nil { latency = CFAbsoluteTimeGetCurrent() - startTime }
                }
            }
            usleep(interval)
        }
        return latency
    }
}
