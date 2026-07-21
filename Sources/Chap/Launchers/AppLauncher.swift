import ApplicationServices
import Cocoa
import os

/// macOS 앱을 실행하고 Accessibility API로 윈도우를 리사이즈하는 런처
enum AppLauncher {
    private static let observationRegistry = ResizeObservationRegistry()

    /// macOS가 실제 앱 식별에 쓰는 CFBundleIdentifier allowlist.
    ///
    /// `com.microsoft.` prefix로 판별하면 Teams/Outlook 같은 비대상 앱까지 걸릴 수 있다.
    /// 시작창 -> 문서창 전환이 잦은 문서형 Office 앱만 명시 목록으로 제한한다.
    /// PowerPoint의 ID는 제품명 표기와 다르게 `Powerpoint`가 맞다.
    private static let microsoftOfficeBundleIds: Set<String> = [
        "com.microsoft.Powerpoint",
        "com.microsoft.Excel",
        "com.microsoft.Word",
        "com.microsoft.onenote.mac",
    ]

    private struct ResizeObservationPolicy {
        let isMicrosoftOffice: Bool
        let timeout: TimeInterval
        let postResizeGrace: TimeInterval
    }

    private struct ResizeObservationResult {
        let latency: TimeInterval?
        let wasSuperseded: Bool
    }

    /// 같은 앱을 연속 실행하면 이전 AXObserver가 Office grace 시간 동안 남아 중복 스캔한다.
    /// 앱별 generation token으로 최신 관찰만 유지하고, 이전 관찰은 다음 루프에서 종료시킨다.
    private final class ResizeObservationRegistry {
        private let lock = NSLock()
        private var tokensByKey: [String: Int] = [:]

        func begin(key: String) -> Int {
            lock.lock()
            defer { lock.unlock() }
            let nextToken = (tokensByKey[key] ?? 0) + 1
            tokensByKey[key] = nextToken
            return nextToken
        }

        func isCurrent(key: String, token: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return tokensByKey[key] == token
        }

        func finish(key: String, token: Int) {
            lock.lock()
            defer { lock.unlock() }
            if tokensByKey[key] == token {
                tokensByKey.removeValue(forKey: key)
            }
        }
    }

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
            Log.launcher.info(
                "No display available — launching \(site.name, privacy: .private) without resize")
            let appURL = URL(fileURLWithPath: path)
            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { _, _ in
                onComplete?()
            }
            return
        }
        let bounds = centeredBounds(for: site, on: screen)
        let bw = bounds.right - bounds.left
        let bh = bounds.bottom - bounds.top

        Log.launcher.info(
            "AppLauncher launch site=\(site.name, privacy: .private) path=\(path, privacy: .private) bundleId=\(bundleId ?? "nil", privacy: .private)"
        )
        Log.launcher.info(
            "AppLauncher target screen=\(screen.localizedName, privacy: .public) bounds={left:\(bounds.left), top:\(bounds.top), w:\(bw), h:\(bh)} requested=\(site.width)x\(site.height, privacy: .public)"
        )

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
                Log.launcher.error(
                    "openApplication failed: \(error.localizedDescription, privacy: .public)")
                onComplete?()
                return
            }
            guard let app = app else {
                onComplete?()
                return
            }
            Log.launcher.info(
                "app opened pid=\(app.processIdentifier) localizedName=\(app.localizedName ?? "?", privacy: .private)"
            )

            let position = CGPoint(x: bounds.left, y: bounds.top)
            let size = CGSize(width: bw, height: bh)
            let policy = resizeObservationPolicy(
                bundleId: app.bundleIdentifier ?? bundleId,
                appRunning: appRunning
            )
            let observationKey = app.bundleIdentifier ?? bundleId ?? "pid:\(app.processIdentifier)"
            let observationToken = observationRegistry.begin(key: observationKey)
            if policy.isMicrosoftOffice {
                Log.launcher.info(
                    "Microsoft Office observation policy for \(site.name, privacy: .private): timeout=\(policy.timeout, privacy: .public)s postResizeGrace=\(policy.postResizeGrace, privacy: .public)s"
                )
            }

            // 공유 resizeQueue 대신 전용 백그라운드 큐 사용 — 관찰(run loop)이
            // 길게 유지될 수 있어 다른 런처(Chrome 등)의 리사이즈를 막지 않도록 함.
            DispatchQueue.global(qos: .userInitiated).async {
                let result = observeAndCenter(
                    pid: app.processIdentifier,
                    position: position,
                    size: size,
                    startTime: startTime,
                    policy: policy,
                    debugLabel: site.name,
                    observationKey: observationKey,
                    observationToken: observationToken
                )
                if result.wasSuperseded {
                    Log.launcher.info(
                        "AX observation superseded for \(site.name, privacy: .private)"
                    )
                    onComplete?()
                    return
                }
                let latency = result.latency
                if let latency {
                    Log.launcher.notice(
                        "AX resize success for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s"
                    )
                } else {
                    Log.launcher.error(
                        "AX resize failed for \(site.name, privacy: .private) — \(CFAbsoluteTimeGetCurrent() - startTime, format: .fixed(precision: 2))s"
                    )
                }
                ResizeLogger.log(
                    site: site.name, type: "app",
                    appState: appRunning ? "running" : "cold",
                    attempt: 1, delay: 0,
                    totalTime: latency ?? (CFAbsoluteTimeGetCurrent() - startTime),
                    result: latency != nil ? "success" : "failed",
                    windowCount: 0,
                    display: screen.localizedName,
                    size: "\(bw)x\(bh)")
                onComplete?()
            }
        }
    }

    // MARK: - AX API Resize

    private static func resizeObservationPolicy(
        bundleId: String?,
        appRunning: Bool
    ) -> ResizeObservationPolicy {
        let baseTimeout: TimeInterval = appRunning ? 8.0 : 20.0
        guard let bundleId, microsoftOfficeBundleIds.contains(bundleId) else {
            return ResizeObservationPolicy(
                isMicrosoftOffice: false,
                timeout: baseTimeout,
                postResizeGrace: 3.0
            )
        }

        // Office 시작창은 AX상 표준 윈도우라서 첫 리사이즈가 성공으로 보인다.
        // 이후 실제 문서창이 늦게 생성될 수 있으므로 Office에 한해 관찰 시간을 늘린다.
        return ResizeObservationPolicy(
            isMicrosoftOffice: true,
            timeout: max(baseTimeout, 30.0),
            postResizeGrace: 20.0
        )
    }

    /// 윈도우 리사이즈 대상/상태를 AXObserver 콜백과 공유하기 위한 컨텍스트.
    /// 콜백과 초기 정렬이 모두 같은 (run loop) 스레드에서 실행되므로 별도 동기화는 불필요.
    private final class ResizeContext {
        let position: CGPoint
        let size: CGSize
        let startTime: CFAbsoluteTime
        let debugLabel: String
        let policy: ResizeObservationPolicy
        let observationKey: String
        let observationToken: Int
        var resized: [AXUIElement] = []
        var skipped: [AXUIElement] = []
        var firstResizeLatency: TimeInterval?
        var lastResizeTime: CFAbsoluteTime?
        var lastSnapshotTime: CFAbsoluteTime = 0
        var didResize: Bool { !resized.isEmpty }
        init(
            position: CGPoint,
            size: CGSize,
            startTime: CFAbsoluteTime,
            debugLabel: String,
            policy: ResizeObservationPolicy,
            observationKey: String,
            observationToken: Int
        ) {
            self.position = position
            self.size = size
            self.startTime = startTime
            self.debugLabel = debugLabel
            self.policy = policy
            self.observationKey = observationKey
            self.observationToken = observationToken
        }
    }

    /// 표준 윈도우(문서 창)면 아직 정렬 안 한 경우에 한해 중앙정렬한다.
    /// Office 시작 화면처럼 표준 subrole이 아니어도 위치/크기를 바꿀 수 있는 창은
    /// Office 앱에 한해 정렬한다. 팔레트/시트처럼 크기 변경 불가능한 창은 건드리지 않는다.
    private static func centerIfStandard(_ window: AXUIElement, ctx: ResizeContext) {
        guard isCurrentObservation(ctx) else { return }
        var subroleValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleValue)
            == .success, let subrole = subroleValue as? String,
            subrole != (kAXStandardWindowSubrole as String)
        {
            if ctx.policy.isMicrosoftOffice, isResizableWindow(window) {
                Log.launcher.info(
                    "AX applying Office non-standard window for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
                )
            } else {
                if !ctx.skipped.contains(where: { CFEqual($0, window) }) {
                    ctx.skipped.append(window)
                    Log.launcher.debug(
                        "AX skip non-standard window for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
                    )
                }
                return
            }
        }
        if ctx.resized.contains(where: { CFEqual($0, window) }) { return }
        Log.launcher.info(
            "AX applying bounds for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
        )
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
        policy: ResizeObservationPolicy, debugLabel: String, observationKey: String,
        observationToken: Int
    ) -> ResizeObservationResult {
        let app = AXUIElementCreateApplication(pid)
        let ctx = ResizeContext(
            position: position,
            size: size,
            startTime: startTime,
            debugLabel: debugLabel,
            policy: policy,
            observationKey: observationKey,
            observationToken: observationToken)

        defer {
            observationRegistry.finish(key: observationKey, token: observationToken)
        }

        guard isCurrentObservation(ctx) else {
            return ResizeObservationResult(latency: nil, wasSuperseded: true)
        }

        var observer: AXObserver?
        let createErr = AXObserverCreate(
            pid,
            { _, element, _, refcon in
                guard let refcon else { return }
                let ctx = Unmanaged<ResizeContext>.fromOpaque(refcon).takeUnretainedValue()
                guard AppLauncher.isCurrentObservation(ctx) else { return }
                Log.launcher.debug(
                    "AX window-created for \(ctx.debugLabel, privacy: .private): title=\(AppLauncher.windowTitle(element), privacy: .private) \(AppLauncher.windowSummary(element), privacy: .public)"
                )
                AppLauncher.centerIfStandard(element, ctx: ctx)
            }, &observer)

        guard createErr == .success, let observer else {
            Log.launcher.error(
                "AXObserverCreate failed err=\(createErr.rawValue, privacy: .public) — falling back to polling"
            )
            return axResizePolling(
                app: app, position: position, size: size, startTime: startTime,
                timeout: policy.timeout,
                debugLabel: debugLabel,
                observationKey: observationKey,
                observationToken: observationToken)
        }

        let refcon = Unmanaged.passUnretained(ctx).toOpaque()
        let addNotificationErr = AXObserverAddNotification(
            observer, app, kAXWindowCreatedNotification as CFString, refcon)
        Log.launcher.info(
            "AX observer add window-created for \(debugLabel, privacy: .private) err=\(addNotificationErr.rawValue, privacy: .public)"
        )

        let runLoop = CFRunLoopGetCurrent()
        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(runLoop, source, .defaultMode)

        // 이미 떠 있는 윈도우 즉시 정렬 + 주기적 재스캔(창 생성 알림 누락 보완).
        // 첫 정렬 이후에는 grace 동안 새 창이 없으면 종료한다. 일반 앱은 3초면 충분하지만,
        // Office 앱은 "Open new and recent files" 같은 시작창도 AXStandardWindow로 노출된 뒤
        // 사용자가 템플릿/파일을 선택하면 실제 문서창이 늦게 생길 수 있어 더 오래 관찰한다.
        // 스캔 간격 0.1s: 옵저버 콜백이 누락된 경우에도 창 등장 후 최대 0.1초 내에 정렬해
        // "창이 잠깐 기본 위치에 보였다가 이동"하는 깜빡임을 최소화한다.
        let hardDeadline = CFAbsoluteTimeGetCurrent() + policy.timeout
        logWindowSnapshot(app: app, ctx: ctx, reason: "start")
        while CFAbsoluteTimeGetCurrent() < hardDeadline && isCurrentObservation(ctx) {
            logWindowSnapshotIfNeeded(app: app, ctx: ctx)
            for win in axWindows(app) {
                centerIfStandard(win, ctx: ctx)
            }
            CFRunLoopRunInMode(.defaultMode, 0.1, false)
            if let last = ctx.lastResizeTime,
                CFAbsoluteTimeGetCurrent() - last >= policy.postResizeGrace
            {
                break
            }
        }

        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        AXObserverRemoveNotification(observer, app, kAXWindowCreatedNotification as CFString)
        guard isCurrentObservation(ctx) else {
            return ResizeObservationResult(latency: nil, wasSuperseded: true)
        }
        if ctx.firstResizeLatency == nil {
            logWindowSnapshot(app: app, ctx: ctx, reason: "timeout", asError: true)
        }
        return ResizeObservationResult(latency: ctx.firstResizeLatency, wasSuperseded: false)
    }

    /// AXObserver를 못 쓸 때의 폴백: 포커스된 표준 윈도우를 폴링하며 정렬.
    /// 첫 정렬까지의 지연시간(초)을 반환하고, 못 잡으면 nil.
    private static func axResizePolling(
        app: AXUIElement, position: CGPoint, size: CGSize, startTime: CFAbsoluteTime,
        timeout: TimeInterval, debugLabel: String, observationKey: String, observationToken: Int
    ) -> ResizeObservationResult {
        let interval: useconds_t = 120_000
        let deadline = CFAbsoluteTimeGetCurrent() + timeout
        var lastResized: AXUIElement?
        var latency: TimeInterval?
        var lastSnapshotTime: CFAbsoluteTime = 0
        while CFAbsoluteTimeGetCurrent() < deadline
            && observationRegistry.isCurrent(key: observationKey, token: observationToken)
        {
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastSnapshotTime >= 1.0 {
                lastSnapshotTime = now
                let windows = axWindows(app)
                Log.launcher.debug(
                    "AX polling snapshot for \(debugLabel, privacy: .private): windows=\(windows.count, privacy: .public) focused=\(focusedWindowSummary(app), privacy: .public)"
                )
                for (index, window) in windows.enumerated() {
                    Log.launcher.debug(
                        "AX polling window[\(index, privacy: .public)] for \(debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
                    )
                }
            }
            var windowValue: AnyObject?
            if AXUIElementCopyAttributeValue(
                app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
                let windowValue
            {
                guard let win = axElement(from: windowValue) else {
                    usleep(interval)
                    continue
                }
                var subroleValue: AnyObject?
                let isStandard =
                    !(AXUIElementCopyAttributeValue(
                        win, kAXSubroleAttribute as CFString, &subroleValue) == .success
                    && (subroleValue as? String) != nil
                    && (subroleValue as? String) != (kAXStandardWindowSubrole as String))
                let isNewWindow = lastResized.map { !CFEqual($0, win) } ?? true
                if isStandard, isNewWindow {
                    LauncherUtils.axApplyBounds(win, position: position, size: size)
                    lastResized = win
                    if latency == nil { latency = CFAbsoluteTimeGetCurrent() - startTime }
                }
            }
            usleep(interval)
        }
        let wasSuperseded = !observationRegistry.isCurrent(
            key: observationKey,
            token: observationToken
        )
        return ResizeObservationResult(latency: latency, wasSuperseded: wasSuperseded)
    }

    private static func logWindowSnapshotIfNeeded(app: AXUIElement, ctx: ResizeContext) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - ctx.lastSnapshotTime >= 1.0 else { return }
        logWindowSnapshot(app: app, ctx: ctx, reason: "scan")
    }

    private static func logWindowSnapshot(
        app: AXUIElement, ctx: ResizeContext, reason: String, asError: Bool = false
    ) {
        ctx.lastSnapshotTime = CFAbsoluteTimeGetCurrent()
        let windows = axWindows(app)
        if asError {
            Log.launcher.error(
                "AX window snapshot for \(ctx.debugLabel, privacy: .private) reason=\(reason, privacy: .public) windows=\(windows.count, privacy: .public) focused=\(focusedWindowSummary(app), privacy: .public)"
            )
            for (index, window) in windows.enumerated() {
                Log.launcher.error(
                    "AX window[\(index, privacy: .public)] for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
                )
            }
            return
        }
        Log.launcher.debug(
            "AX window snapshot for \(ctx.debugLabel, privacy: .private) reason=\(reason, privacy: .public) windows=\(windows.count, privacy: .public) focused=\(focusedWindowSummary(app), privacy: .public)"
        )
        for (index, window) in windows.enumerated() {
            Log.launcher.debug(
                "AX window[\(index, privacy: .public)] for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
            )
        }
    }

    private static func isCurrentObservation(_ ctx: ResizeContext) -> Bool {
        observationRegistry.isCurrent(key: ctx.observationKey, token: ctx.observationToken)
    }

    private static func axElement(from value: AnyObject) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        // Swift cannot conditionally cast CoreFoundation AXUIElement values without
        // warning; the CFTypeID guard above proves this downcast.
        return (value as! AXUIElement)
    }

    private static func axValue(from value: AnyObject) -> AXValue? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        // Swift cannot conditionally cast CoreFoundation AXValue values without
        // warning; the CFTypeID guard above proves this downcast.
        return (value as! AXValue)
    }

    private static func focusedWindowSummary(_ app: AXUIElement) -> String {
        var value: AnyObject?
        guard
            AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
                == .success,
            let value,
            let window = axElement(from: value)
        else {
            return "none"
        }
        return windowSummary(window)
    }

    private static func windowSummary(_ window: AXUIElement) -> String {
        let role = stringAttribute(window, kAXRoleAttribute as CFString)
        let subrole = stringAttribute(window, kAXSubroleAttribute as CFString)
        let position = pointAttribute(window, kAXPositionAttribute as CFString)
        let size = sizeAttribute(window, kAXSizeAttribute as CFString)
        let positionSettable = isSettable(window, kAXPositionAttribute as CFString)
        let sizeSettable = isSettable(window, kAXSizeAttribute as CFString)
        return
            "role=\(role) subrole=\(subrole) position=\(position) size=\(size) canSetPosition=\(positionSettable) canSetSize=\(sizeSettable)"
    }

    private static func isResizableWindow(_ window: AXUIElement) -> Bool {
        stringAttribute(window, kAXRoleAttribute as CFString) == (kAXWindowRole as String)
            && isAttributeSettable(window, kAXPositionAttribute as CFString)
            && isAttributeSettable(window, kAXSizeAttribute as CFString)
    }

    private static func windowTitle(_ window: AXUIElement) -> String {
        stringAttribute(window, kAXTitleAttribute as CFString)
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success, let value
        else {
            return "nil"
        }
        return String(describing: value)
    }

    private static func pointAttribute(_ element: AXUIElement, _ attribute: CFString) -> String {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            let axValue = axValue(from: value)
        else {
            return "nil"
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return "unreadable" }
        return "(\(Int(point.x)),\(Int(point.y)))"
    }

    private static func sizeAttribute(_ element: AXUIElement, _ attribute: CFString) -> String {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            let axValue = axValue(from: value)
        else {
            return "nil"
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return "unreadable" }
        return "\(Int(size.width))x\(Int(size.height))"
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: CFString) -> String {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
        guard error == .success else { return "error:\(error.rawValue)" }
        return settable.boolValue ? "true" : "false"
    }

    private static func isAttributeSettable(_ element: AXUIElement, _ attribute: CFString) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success
            && settable.boolValue
    }
}
