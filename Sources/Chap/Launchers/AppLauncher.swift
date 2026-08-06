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
        /// 리사이즈 대상 창을 아예 못 찾았을 때의 창 상태 요약. 찾은 경우 nil.
        let diagnostic: String?

        static let superseded = ResizeObservationResult(
            latency: nil, wasSuperseded: true, boundsResult: nil, diagnostic: nil)
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
            onComplete?()
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            Log.launcher.error("App not found at: \(path, privacy: .private)")
            LauncherUtils.showAlert(message: "App not found at: \(path)")
            onComplete?()
            return
        }

        let bundle = Bundle(path: path)
        let bundleId = bundle?.bundleIdentifier

        guard let screen = targetScreen(for: site) else {
            Log.launcher.info(
                "No display available — launching \(site.name, privacy: .private) without resize")
            openWithoutResize(path: path, onComplete: onComplete)
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

        guard AccessibilityPermission.isTrusted else {
            Log.launcher.info("Accessibility not granted — launching without resize")
            openWithoutResize(path: path, onComplete: onComplete)
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
            windowsBefore = LauncherUtils.captureExistingWindows(pid: pid)
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
                let detail: String
                if let boundsResult = result.boundsResult {
                    resultLabel = boundsResult.level.rawValue
                    detail = boundsResult.diagnostic
                    switch boundsResult.level {
                    case .fullyApplied:
                        Log.launcher.notice(
                            "AX resize verified for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s"
                        )
                    case .partiallyApplied:
                        Log.launcher.warning(
                            "AX resize partially applied for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                        )
                    case .failed:
                        Log.launcher.error(
                            "AX resize verification failed for \(site.name, privacy: .private) — \(latency, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                        )
                        AccessibilityPermission.notifyResizeFailure()
                    }
                } else {
                    resultLabel = "failed"
                    detail = result.diagnostic ?? "no eligible window found"
                    Log.launcher.error(
                        "AX resize failed for \(site.name, privacy: .private) — \(elapsed, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                    )
                    AccessibilityPermission.notifyResizeFailure()
                }
                ResizeLogger.log(
                    site: site.name, type: "app",
                    appState: appRunning ? "running" : "cold",
                    attempt: 1, delay: 0,
                    totalTime: latency,
                    result: resultLabel,
                    windowCount: windowsBefore.count,
                    display: screen.localizedName,
                    size: "\(bw)x\(bh)",
                    detail: detail)
                onComplete?()
            }
        }
    }

    /// 리사이즈 없이 앱만 실행 (화면 없음 / 접근성 미허용 경로 공용)
    private static func openWithoutResize(path: String, onComplete: (() -> Void)?) {
        let appURL = URL(fileURLWithPath: path)
        let openConfig = NSWorkspace.OpenConfiguration()
        openConfig.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { _, _ in
            onComplete?()
        }
    }

    // MARK: - Observation policy

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

    // MARK: - Resize context

    /// 윈도우 리사이즈 대상/상태를 AXObserver 콜백과 관찰 루프가 공유하는 컨텍스트.
    /// 콜백과 루프가 모두 같은 (run loop) 스레드에서 실행되므로 별도 동기화는 불필요.
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
        var processedWindows: [AXUIElement] = []
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

        func hasProcessed(_ window: AXUIElement) -> Bool {
            processedWindows.contains { CFEqual($0, window) }
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
                    "AX skip ineligible window for \(ctx.debugLabel, privacy: .private): title=\(AXIntrospection.windowTitle(window), privacy: .private) \(AXIntrospection.windowSummary(window), privacy: .public)"
                )
            }
            return
        }

        guard ctx.isNewWindow(window), !ctx.hasProcessed(window) else { return }

        // 비-Office는 첫 새 창 하나만, Office는 새 문서창이 나타날 때마다 교체
        guard ctx.policy.isMicrosoftOffice || ctx.resizedWindow == nil else { return }

        let boundsResult = applyBoundsToWindow(window, ctx: ctx)
        if boundsResult.applied {
            ctx.processedWindows.append(window)
        }
    }

    /// 실제 bounds 적용 + 결과 기록
    @discardableResult
    private static func applyBoundsToWindow(_ window: AXUIElement, ctx: ResizeContext)
        -> AXBoundsResult
    {
        Log.launcher.info(
            "AX applying bounds for \(ctx.debugLabel, privacy: .private): title=\(AXIntrospection.windowTitle(window), privacy: .private) \(AXIntrospection.windowSummary(window), privacy: .public)"
        )
        let boundsResult = LauncherUtils.axApplyBounds(
            window, position: ctx.position, size: ctx.size)
        ctx.resizedBoundsResult = boundsResult
        let now = CFAbsoluteTimeGetCurrent()
        if boundsResult.applied {
            if ctx.firstResizeLatency == nil { ctx.firstResizeLatency = now - ctx.startTime }
            ctx.resizedWindow = window
            ctx.lastResizeTime = now
        }
        Log.launcher.info(
            "AX bounds result for \(ctx.debugLabel, privacy: .private): level=\(boundsResult.level.rawValue, privacy: .public) pos=\(boundsResult.positionWithinTolerance) size=\(boundsResult.sizeWithinTolerance)"
        )
        return boundsResult
    }

    static func shouldEndObservationAfterFocusedFallback(
        didResize: Bool, isMicrosoftOffice: Bool
    ) -> Bool {
        didResize && !isMicrosoftOffice
    }

    // MARK: - Observation loop

    /// AXObserver로 윈도우 생성을 구독하고, baseline 대비 새 창 하나를 리사이즈.
    /// 옵저버 생성이 실패하면 같은 루프를 usleep 폴링으로 수행한다 (관찰 로직 공용).
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

        guard isCurrentObservation(ctx) else { return .superseded }

        var observer: AXObserver?
        let createErr = AXObserverCreate(
            pid,
            { _, element, _, refcon in
                guard let refcon else { return }
                let ctx = Unmanaged<ResizeContext>.fromOpaque(refcon).takeUnretainedValue()
                guard AppLauncher.isCurrentObservation(ctx) else { return }
                Log.launcher.debug(
                    "AX window-created for \(ctx.debugLabel, privacy: .private): title=\(AXIntrospection.windowTitle(element), privacy: .private) \(AXIntrospection.windowSummary(element), privacy: .public)"
                )
                AppLauncher.resizeIfNewStandardWindow(element, ctx: ctx)
            }, &observer)

        guard createErr == .success, let observer else {
            Log.launcher.error(
                "AXObserverCreate failed err=\(createErr.rawValue, privacy: .public) — falling back to polling"
            )
            runResizeLoop(app: app, ctx: ctx) { usleep(120_000) }
            return finishObservation(app: app, ctx: ctx)
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
        runResizeLoop(app: app, ctx: ctx) { CFRunLoopRunInMode(.defaultMode, 0.05, false) }
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        AXObserverRemoveNotification(observer, app, kAXWindowCreatedNotification as CFString)

        return finishObservation(app: app, ctx: ctx)
    }

    /// 옵저버/폴링 공용 관찰 루프.
    /// 매 사이클: 스냅샷 로깅 → baseline 대비 새 창 스캔 → 대기(wait) →
    /// focusedFallbackDelay 경과 시 early focused fallback → 마지막 리사이즈 후
    /// postResizeGrace가 지나면 종료 (Office는 grace 동안 새 문서창을 계속 대기).
    ///
    /// - Parameter wait: 사이클 간 대기. 옵저버 경로는 run loop 펌핑(콜백 처리),
    ///   폴링 경로는 usleep.
    private static func runResizeLoop(
        app: AXUIElement, ctx: ResizeContext, wait: () -> Void
    ) {
        let hardDeadline = CFAbsoluteTimeGetCurrent() + ctx.policy.timeout
        logWindowSnapshot(app: app, ctx: ctx, reason: "start")
        while CFAbsoluteTimeGetCurrent() < hardDeadline && isCurrentObservation(ctx) {
            logWindowSnapshotIfNeeded(app: app, ctx: ctx)
            // baseline 대비 새 창만 시도
            for win in LauncherUtils.axWindows(app: app) where ctx.isNewWindow(win) {
                resizeIfNewStandardWindow(win, ctx: ctx)
            }
            wait()

            let elapsed = CFAbsoluteTimeGetCurrent() - ctx.startTime
            if !ctx.didResize, !ctx.didAttemptEarlyFocusedFallback,
                elapsed >= ctx.policy.focusedFallbackDelay
            {
                ctx.didAttemptEarlyFocusedFallback = true
                Log.launcher.info(
                    "AX trying early focused fallback for \(ctx.debugLabel, privacy: .private) after \(elapsed, format: .fixed(precision: 2))s"
                )
                _ = focusedWindowFallback(app: app, ctx: ctx)
                if shouldEndObservationAfterFocusedFallback(
                    didResize: ctx.didResize,
                    isMicrosoftOffice: ctx.policy.isMicrosoftOffice)
                {
                    break
                }
            }

            // 마지막 리사이즈 후 grace가 지나면 종료
            if let last = ctx.lastResizeTime,
                CFAbsoluteTimeGetCurrent() - last >= ctx.policy.postResizeGrace
            {
                break
            }
        }
    }

    /// 관찰 루프 종료 후 결과 조립. 새 창 리사이즈가 없었으면 focused fallback을
    /// 한 번 더 시도하고, 그래도 실패면 창 상태 진단을 남긴다.
    private static func finishObservation(app: AXUIElement, ctx: ResizeContext)
        -> ResizeObservationResult
    {
        guard isCurrentObservation(ctx) else { return .superseded }

        if ctx.didResize {
            return ResizeObservationResult(
                latency: ctx.firstResizeLatency, wasSuperseded: false,
                boundsResult: ctx.resizedBoundsResult, diagnostic: nil)
        }

        let boundsResult = focusedWindowFallback(app: app, ctx: ctx)
        var diagnostic: String?
        if ctx.firstResizeLatency == nil {
            logWindowSnapshot(app: app, ctx: ctx, reason: "timeout", asError: true)
            diagnostic = AXIntrospection.windowStateDiagnostic(app: app)
        }
        return ResizeObservationResult(
            latency: ctx.firstResizeLatency, wasSuperseded: false,
            boundsResult: boundsResult ?? ctx.resizedBoundsResult,
            diagnostic: diagnostic)
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
        guard let win = AXIntrospection.element(from: windowValue),
            isEligibleResizeWindow(win, policy: ctx.policy)
        else { return nil }

        Log.launcher.info(
            "AX focused-window fallback for \(ctx.debugLabel, privacy: .private): title=\(AXIntrospection.windowTitle(win), privacy: .private) \(AXIntrospection.windowSummary(win), privacy: .public)"
        )
        let boundsResult = applyBoundsToWindow(win, ctx: ctx)
        if boundsResult.applied, ctx.isNewWindow(win), !ctx.hasProcessed(win) {
            ctx.processedWindows.append(win)
        }
        Log.launcher.info(
            "AX focused fallback result for \(ctx.debugLabel, privacy: .private): level=\(boundsResult.level.rawValue, privacy: .public)"
        )
        return boundsResult
    }

    // MARK: - Eligibility

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
            canSetPosition: AXIntrospection.isAttributeSettable(
                window, kAXPositionAttribute as CFString),
            canSetSize: AXIntrospection.isAttributeSettable(
                window, kAXSizeAttribute as CFString),
            isMicrosoftOffice: policy.isMicrosoftOffice)
    }

    // MARK: - Logging helpers

    private static func isCurrentObservation(_ ctx: ResizeContext) -> Bool {
        observationRegistry.isCurrent(key: ctx.observationKey, token: ctx.observationToken)
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
        let windows = LauncherUtils.axWindows(app: app)
        if asError {
            Log.launcher.error(
                "AX window snapshot for \(ctx.debugLabel, privacy: .private) reason=\(reason, privacy: .public) windows=\(windows.count, privacy: .public) focused=\(AXIntrospection.focusedWindowSummary(app), privacy: .public)"
            )
            for (index, window) in windows.enumerated() {
                Log.launcher.error(
                    "AX window[\(index, privacy: .public)] for \(ctx.debugLabel, privacy: .private): title=\(AXIntrospection.windowTitle(window), privacy: .private) \(AXIntrospection.windowSummary(window), privacy: .public)"
                )
            }
            return
        }
        Log.launcher.debug(
            "AX window snapshot for \(ctx.debugLabel, privacy: .private) reason=\(reason, privacy: .public) windows=\(windows.count, privacy: .public) focused=\(AXIntrospection.focusedWindowSummary(app), privacy: .public)"
        )
        for (index, window) in windows.enumerated() {
            Log.launcher.debug(
                "AX window[\(index, privacy: .public)] for \(ctx.debugLabel, privacy: .private): title=\(AXIntrospection.windowTitle(window), privacy: .private) \(AXIntrospection.windowSummary(window), privacy: .public)"
            )
        }
    }
}
