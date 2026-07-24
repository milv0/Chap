import ApplicationServices
import Cocoa
import os

/// macOS 앱을 실행하고 Accessibility API로 윈도우를 리사이즈하는 런처
///
/// 정책:
/// - 실행 전 baseline을 기록하고, 새 창이 나타나면 하나만 처리한다 (첫 번째 새 창).
/// - 실행 중 앱은 짧은 새 창 grace 후, cold 앱은 timeout 후 focused window 하나를 fallback 처리한다.
/// - "기존 모든 창을 리사이즈"하는 동작은 금지.
/// - Office 앱은 시작창 → 문서창 전환이 있으므로 새 문서창 대기 정책을 유지한다.
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
        let focusedFallbackDelay: TimeInterval
    }

    private struct ResizeObservationResult {
        let latency: TimeInterval?
        let wasSuperseded: Bool
        let boundsResult: AXBoundsResult?
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

        // 실행 전 baseline: 현재 윈도우 집합 기록
        let baselinePid: pid_t? = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleId
        }?.processIdentifier
        let windowsBefore: [AXUIElement]
        if let pid = baselinePid {
            windowsBefore = captureExistingWindows(pid: pid)
        } else {
            windowsBefore = []
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
                    "Microsoft Office observation policy for \(site.name, privacy: .private): timeout=\(policy.timeout, privacy: .public)s postResizeGrace=\(policy.postResizeGrace, privacy: .public)s focusedFallbackDelay=\(policy.focusedFallbackDelay, privacy: .public)s"
                )
            }

            // 관찰(run loop)이 길게 유지될 수 있으므로 전용 백그라운드 큐에서 실행해
            // 다른 런처(Chrome 등)의 작업을 막지 않도록 한다.
            DispatchQueue.global(qos: .userInitiated).async {
                let result = observeAndResizeOneWindow(
                    pid: app.processIdentifier,
                    position: position,
                    size: size,
                    startTime: startTime,
                    policy: policy,
                    debugLabel: site.name,
                    observationKey: observationKey,
                    observationToken: observationToken,
                    windowsBefore: windowsBefore
                )
                if result.wasSuperseded {
                    Log.launcher.info(
                        "AX observation superseded for \(site.name, privacy: .private)"
                    )
                    onComplete?()
                    return
                }
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                let latency = result.latency ?? elapsed
                let resultLabel: String
                if let boundsResult = result.boundsResult {
                    resultLabel = boundsResult.level.rawValue
                    switch boundsResult.level {
                    case .fullyApplied:
                        Log.launcher.notice(
                            "AX resize verified for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s"
                        )
                    case .partiallyApplied:
                        Log.launcher.warning(
                            "AX resize partially applied for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s"
                        )
                    case .failed:
                        Log.launcher.error(
                            "AX resize verification failed for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s"
                        )
                    }
                } else {
                    resultLabel = "failed"
                    Log.launcher.error(
                        "AX resize failed for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s"
                    )
                }
                ResizeLogger.log(
                    site: site.name, type: "app",
                    appState: appRunning ? "running" : "cold",
                    attempt: 1, delay: 0,
                    totalTime: latency,
                    result: resultLabel,
                    windowCount: windowsBefore.count,
                    display: screen.localizedName,
                    size: "\(bw)x\(bh)")
                onComplete?()
            }
        }
    }

    // MARK: - AX API Resize

    /// 실행 중 앱은 이미 문서창이 떠 있는 경우가 많아, 새 창을 짧게만 기다린 뒤
    /// focused 창을 리사이즈한다. 이 지연은 실제로 새 창이 뜰 때 시작창을 잘못 잡지
    /// 않게 하는 최소 여유이며, 진짜 새 창은 AXObserver 콜백이 즉시 처리한다.
    static func focusedFallbackDelay(appRunning: Bool, timeout: TimeInterval) -> TimeInterval {
        appRunning ? 0.2 : timeout
    }

    private static func resizeObservationPolicy(
        bundleId: String?,
        appRunning: Bool
    ) -> ResizeObservationPolicy {
        let baseTimeout: TimeInterval = appRunning ? 8.0 : 20.0
        guard let bundleId, microsoftOfficeBundleIds.contains(bundleId) else {
            return ResizeObservationPolicy(
                isMicrosoftOffice: false,
                timeout: baseTimeout,
                postResizeGrace: 3.0,
                focusedFallbackDelay: focusedFallbackDelay(
                    appRunning: appRunning, timeout: baseTimeout)
            )
        }

        // Office 시작창은 AX상 표준 윈도우라서 첫 리사이즈가 성공으로 보인다.
        // 이후 실제 문서창이 늦게 생성될 수 있으므로 Office에 한해 관찰 시간을 늘린다.
        let officeTimeout = max(baseTimeout, 30.0)
        return ResizeObservationPolicy(
            isMicrosoftOffice: true,
            timeout: officeTimeout,
            postResizeGrace: 20.0,
            focusedFallbackDelay: focusedFallbackDelay(
                appRunning: appRunning, timeout: officeTimeout)
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
        let windowsBefore: [AXUIElement]
        /// 리사이즈에 성공한 새 창 (최대 1개; Office는 문서창을 대기해 교체 가능)
        var resizedWindow: AXUIElement?
        var resizedBoundsResult: AXBoundsResult?
        var skipped: [AXUIElement] = []
        var firstResizeLatency: TimeInterval?
        var lastResizeTime: CFAbsoluteTime?
        var lastSnapshotTime: CFAbsoluteTime = 0
        var didAttemptEarlyFocusedFallback = false
        var didResize: Bool { resizedWindow != nil }
        init(
            position: CGPoint,
            size: CGSize,
            startTime: CFAbsoluteTime,
            debugLabel: String,
            policy: ResizeObservationPolicy,
            observationKey: String,
            observationToken: Int,
            windowsBefore: [AXUIElement]
        ) {
            self.position = position
            self.size = size
            self.startTime = startTime
            self.debugLabel = debugLabel
            self.policy = policy
            self.observationKey = observationKey
            self.observationToken = observationToken
            self.windowsBefore = windowsBefore
        }

        /// 이 윈도우가 baseline에 없는 새 창인지 판별
        func isNewWindow(_ window: AXUIElement) -> Bool {
            !windowsBefore.contains { CFEqual($0, window) }
        }
    }

    /// 새 창 하나를 우선 처리. Office 앱은 새 문서창이 나타나면 이전 리사이즈를 교체.
    /// 새 창이 이미 처리된(비-Office) 경우 추가 창은 무시.
    private static func resizeIfNewStandardWindow(_ window: AXUIElement, ctx: ResizeContext) {
        guard isCurrentObservation(ctx) else { return }
        guard isEligibleResizeWindow(window, policy: ctx.policy) else {
            if !ctx.skipped.contains(where: { CFEqual($0, window) }) {
                ctx.skipped.append(window)
                Log.launcher.debug(
                    "AX skip ineligible window for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
                )
            }
            return
        }

        let isNew = ctx.isNewWindow(window)
        guard isNew else { return }

        if ctx.policy.isMicrosoftOffice {
            if let resizedWindow = ctx.resizedWindow, CFEqual(resizedWindow, window) {
                return
            }
            applyBoundsToWindow(window, ctx: ctx)
            return
        }

        if ctx.resizedWindow == nil {
            applyBoundsToWindow(window, ctx: ctx)
        }
    }

    /// 실제 bounds 적용 + 결과 기록
    private static func applyBoundsToWindow(_ window: AXUIElement, ctx: ResizeContext) {
        Log.launcher.info(
            "AX applying bounds for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(window), privacy: .private) \(windowSummary(window), privacy: .public)"
        )
        let boundsResult = LauncherUtils.axApplyBounds(
            window, position: ctx.position, size: ctx.size)
        ctx.resizedBoundsResult = boundsResult
        let now = CFAbsoluteTimeGetCurrent()
        if ctx.firstResizeLatency == nil { ctx.firstResizeLatency = now - ctx.startTime }
        if boundsResult.applied {
            ctx.resizedWindow = window
            ctx.lastResizeTime = now
        }
        Log.launcher.info(
            "AX bounds result for \(ctx.debugLabel, privacy: .private): level=\(boundsResult.level.rawValue, privacy: .public) pos=\(boundsResult.positionWithinTolerance) size=\(boundsResult.sizeWithinTolerance)"
        )
    }

    private static func axWindows(_ app: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        guard
            AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    /// AXObserver로 윈도우 생성을 구독하고, baseline 대비 새 창 하나를 리사이즈.
    /// 실행 중 앱은 짧은 grace 후, cold 앱은 timeout 후 focused window 하나를 fallback.
    private static func observeAndResizeOneWindow(
        pid: pid_t, position: CGPoint, size: CGSize, startTime: CFAbsoluteTime,
        policy: ResizeObservationPolicy, debugLabel: String, observationKey: String,
        observationToken: Int, windowsBefore: [AXUIElement]
    ) -> ResizeObservationResult {
        let app = AXUIElementCreateApplication(pid)
        let ctx = ResizeContext(
            position: position,
            size: size,
            startTime: startTime,
            debugLabel: debugLabel,
            policy: policy,
            observationKey: observationKey,
            observationToken: observationToken,
            windowsBefore: windowsBefore)

        defer {
            observationRegistry.finish(key: observationKey, token: observationToken)
        }

        guard isCurrentObservation(ctx) else {
            return ResizeObservationResult(latency: nil, wasSuperseded: true, boundsResult: nil)
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
                AppLauncher.resizeIfNewStandardWindow(element, ctx: ctx)
            }, &observer)

        guard createErr == .success, let observer else {
            Log.launcher.error(
                "AXObserverCreate failed err=\(createErr.rawValue, privacy: .public) — falling back to polling"
            )
            return axResizePolling(
                app: app, position: position, size: size, startTime: startTime,
                policy: policy,
                debugLabel: debugLabel,
                observationKey: observationKey,
                observationToken: observationToken,
                windowsBefore: windowsBefore)
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

        // 이미 떠 있는 새 윈도우 즉시 스캔 + 주기적 재스캔
        let hardDeadline = CFAbsoluteTimeGetCurrent() + policy.timeout
        logWindowSnapshot(app: app, ctx: ctx, reason: "start")
        while CFAbsoluteTimeGetCurrent() < hardDeadline && isCurrentObservation(ctx) {
            logWindowSnapshotIfNeeded(app: app, ctx: ctx)
            // baseline 대비 새 창만 시도
            for win in axWindows(app) where ctx.isNewWindow(win) {
                resizeIfNewStandardWindow(win, ctx: ctx)
            }
            CFRunLoopRunInMode(.defaultMode, 0.05, false)

            let elapsed = CFAbsoluteTimeGetCurrent() - ctx.startTime
            if !ctx.didResize, !ctx.didAttemptEarlyFocusedFallback,
                elapsed >= policy.focusedFallbackDelay
            {
                ctx.didAttemptEarlyFocusedFallback = true
                Log.launcher.info(
                    "AX trying early focused fallback for \(debugLabel, privacy: .private) after \(elapsed, format: .fixed(precision: 2))s"
                )
                _ = focusedWindowFallback(app: app, ctx: ctx)
                if ctx.didResize { break }
            }

            // 일반 앱: 첫 리사이즈 후 grace 지나면 종료
            if !ctx.policy.isMicrosoftOffice, ctx.didResize,
                let last = ctx.lastResizeTime,
                CFAbsoluteTimeGetCurrent() - last >= policy.postResizeGrace
            {
                break
            }
            // Office: grace 동안 새 문서창 계속 대기
            if ctx.policy.isMicrosoftOffice,
                let last = ctx.lastResizeTime,
                CFAbsoluteTimeGetCurrent() - last >= policy.postResizeGrace
            {
                break
            }
        }

        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        AXObserverRemoveNotification(observer, app, kAXWindowCreatedNotification as CFString)
        guard isCurrentObservation(ctx) else {
            return ResizeObservationResult(latency: nil, wasSuperseded: true, boundsResult: nil)
        }

        // 새 창이 하나도 없었을 때만 focused window fallback (하나만)
        if !ctx.didResize {
            let boundsResult = focusedWindowFallback(app: app, ctx: ctx)
            if ctx.firstResizeLatency == nil {
                logWindowSnapshot(app: app, ctx: ctx, reason: "timeout", asError: true)
            }
            return ResizeObservationResult(
                latency: ctx.firstResizeLatency, wasSuperseded: false,
                boundsResult: boundsResult ?? ctx.resizedBoundsResult)
        }

        return ResizeObservationResult(
            latency: ctx.firstResizeLatency, wasSuperseded: false,
            boundsResult: ctx.resizedBoundsResult)
    }

    /// 새 창이 없을 때 focused window 하나만 리사이즈 (fallback)
    private static func focusedWindowFallback(app: AXUIElement, ctx: ResizeContext)
        -> AXBoundsResult?
    {
        var windowValue: AnyObject?
        guard
            AXUIElementCopyAttributeValue(
                app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
            let windowValue
        else { return nil }
        guard let win = axElement(from: windowValue),
            isEligibleResizeWindow(win, policy: ctx.policy)
        else { return nil }

        Log.launcher.info(
            "AX focused-window fallback for \(ctx.debugLabel, privacy: .private): title=\(windowTitle(win), privacy: .private) \(windowSummary(win), privacy: .public)"
        )
        let boundsResult = LauncherUtils.axApplyBounds(
            win, position: ctx.position, size: ctx.size)
        ctx.resizedBoundsResult = boundsResult
        let now = CFAbsoluteTimeGetCurrent()
        if ctx.firstResizeLatency == nil { ctx.firstResizeLatency = now - ctx.startTime }
        if boundsResult.applied {
            ctx.resizedWindow = win
            ctx.lastResizeTime = now
        }
        Log.launcher.info(
            "AX focused fallback result for \(ctx.debugLabel, privacy: .private): level=\(boundsResult.level.rawValue, privacy: .public)"
        )
        return boundsResult
    }

    /// AXObserver를 못 쓸 때의 폴백: 새 창 우선, 없으면 focused window 하나만.
    private static func axResizePolling(
        app: AXUIElement, position: CGPoint, size: CGSize, startTime: CFAbsoluteTime,
        policy: ResizeObservationPolicy, debugLabel: String, observationKey: String,
        observationToken: Int, windowsBefore: [AXUIElement]
    ) -> ResizeObservationResult {
        let interval: useconds_t = 120_000
        let deadline = CFAbsoluteTimeGetCurrent() + policy.timeout
        var resizedWindow: AXUIElement?
        var latency: TimeInterval?
        var boundsResult: AXBoundsResult?
        var lastSnapshotTime: CFAbsoluteTime = 0
        var didAttemptEarlyFocusedFallback = false
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

            // 새 창 우선 탐색
            let windows = axWindows(app)
            let newWindows = windows.filter { win in
                !windowsBefore.contains { CFEqual($0, win) }
            }
            if resizedWindow == nil {
                for newWindow in newWindows
                where isEligibleResizeWindow(newWindow, policy: policy) {
                    let attemptResult = LauncherUtils.axApplyBounds(
                        newWindow, position: position, size: size)
                    boundsResult = attemptResult
                    if latency == nil { latency = CFAbsoluteTimeGetCurrent() - startTime }
                    if attemptResult.applied {
                        resizedWindow = newWindow
                        break
                    }
                }
                if resizedWindow != nil { break }
            }

            if resizedWindow == nil, !didAttemptEarlyFocusedFallback,
                now - startTime >= policy.focusedFallbackDelay
            {
                didAttemptEarlyFocusedFallback = true
                var focusedValue: AnyObject?
                if AXUIElementCopyAttributeValue(
                    app, kAXFocusedWindowAttribute as CFString, &focusedValue) == .success,
                    let focusedValue,
                    let focusedWindow = axElement(from: focusedValue),
                    isEligibleResizeWindow(focusedWindow, policy: policy)
                {
                    Log.launcher.info(
                        "AX polling early focused fallback for \(debugLabel, privacy: .private): title=\(windowTitle(focusedWindow), privacy: .private)"
                    )
                    let attemptResult = LauncherUtils.axApplyBounds(
                        focusedWindow, position: position, size: size)
                    boundsResult = attemptResult
                    if latency == nil { latency = CFAbsoluteTimeGetCurrent() - startTime }
                    if attemptResult.applied {
                        resizedWindow = focusedWindow
                        break
                    }
                }
            }
            usleep(interval)
        }

        // 새 창 못 찾았으면 focused window fallback
        if resizedWindow == nil {
            var windowValue: AnyObject?
            if AXUIElementCopyAttributeValue(
                app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
                let windowValue
            {
                if let win = axElement(from: windowValue),
                    isEligibleResizeWindow(win, policy: policy)
                {
                    Log.launcher.info(
                        "AX polling focused-window fallback for \(debugLabel, privacy: .private): title=\(windowTitle(win), privacy: .private)"
                    )
                    let attemptResult = LauncherUtils.axApplyBounds(
                        win, position: position, size: size)
                    boundsResult = attemptResult
                    if attemptResult.applied {
                        resizedWindow = win
                    }
                    if latency == nil { latency = CFAbsoluteTimeGetCurrent() - startTime }
                }
            }
        }

        let wasSuperseded = !observationRegistry.isCurrent(
            key: observationKey,
            token: observationToken
        )
        return ResizeObservationResult(
            latency: latency, wasSuperseded: wasSuperseded, boundsResult: boundsResult)
    }

    // MARK: - Baseline capture

    /// 실행 전 앱 창 목록 스냅샷. AX 윈도우 읽기가 순간적으로 빈 배열을 반환할 수 있어
    /// 짧게 재시도해 실제 창 집합을 확보한다.
    private static func captureExistingWindows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        for attempt in 0..<5 {
            let windows = axWindows(app)
            if !windows.isEmpty { return windows }
            if attempt < 4 { usleep(30_000) }
        }
        return []
    }

    // MARK: - Logging helpers

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
        return (value as! AXUIElement)
    }

    private static func axValue(from value: AnyObject) -> AXValue? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
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

    static func isEligibleWindowMetadata(
        role: String?, subrole: String?, canSetPosition: Bool, canSetSize: Bool,
        isMicrosoftOffice: Bool
    ) -> Bool {
        guard role == (kAXWindowRole as String), canSetPosition, canSetSize else {
            return false
        }
        if subrole == (kAXStandardWindowSubrole as String) { return true }
        return isMicrosoftOffice
    }

    private static func isEligibleResizeWindow(
        _ window: AXUIElement, policy: ResizeObservationPolicy
    ) -> Bool {
        var roleValue: AnyObject?
        var subroleValue: AnyObject?
        _ = AXUIElementCopyAttributeValue(
            window, kAXRoleAttribute as CFString, &roleValue)
        _ = AXUIElementCopyAttributeValue(
            window, kAXSubroleAttribute as CFString, &subroleValue)
        return isEligibleWindowMetadata(
            role: roleValue as? String,
            subrole: subroleValue as? String,
            canSetPosition: isAttributeSettable(window, kAXPositionAttribute as CFString),
            canSetSize: isAttributeSettable(window, kAXSizeAttribute as CFString),
            isMicrosoftOffice: policy.isMicrosoftOffice)
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
