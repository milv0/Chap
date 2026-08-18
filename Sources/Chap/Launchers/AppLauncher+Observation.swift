import ApplicationServices
import Cocoa
import os

// AXObserver 기반 윈도우 관찰 루프와 fallback/eligibility/logging 헬퍼.
// 동작 변경 없이 AppLauncher.swift에서 분리되었다.
extension AppLauncher {
    // MARK: - New-window processing

    /// 새 창 하나를 우선 처리. Office 앱은 새 문서창이 나타나면 이전 리사이즈를 교체.
    /// 새 창이 이미 처리된(비-Office) 경우 추가 창은 무시.
    static func resizeIfNewStandardWindow(_ window: AXUIElement, ctx: ResizeContext) {
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
        guard
            canResizeNewWindow(
                isMicrosoftOffice: ctx.policy.isMicrosoftOffice,
                alreadyResized: ctx.resizedWindow != nil)
        else { return }

        let boundsResult = applyBoundsToWindow(window, ctx: ctx)
        if boundsResult.applied {
            ctx.processedWindows.append(window)
        }
    }

    static func shouldEndObservationAfterFocusedFallback(
        didResize: Bool, isMicrosoftOffice: Bool
    ) -> Bool {
        didResize && !isMicrosoftOffice
    }

    /// 조기 focused fallback 시도 시점인지 판정. 아직 리사이즈하지 못했고,
    /// 조기 시도를 하지 않았으며, 정책의 focusedFallbackDelay가 경과했을 때 true.
    static func shouldAttemptEarlyFocusedFallback(
        didResize: Bool,
        didAttemptAlready: Bool,
        elapsed: TimeInterval,
        focusedFallbackDelay: TimeInterval
    ) -> Bool {
        !didResize && !didAttemptAlready && elapsed >= focusedFallbackDelay
    }

    /// 마지막 리사이즈 이후 grace period가 만료되었는지 판정.
    /// lastResizeTime이 nil이면 리사이즈된 적 없으므로 grace 종료 조건 불성립.
    static func isGracePeriodExpired(
        lastResizeTime: CFAbsoluteTime?,
        now: CFAbsoluteTime,
        postResizeGrace: TimeInterval
    ) -> Bool {
        guard let last = lastResizeTime else { return false }
        return now - last >= postResizeGrace
    }

    /// 새 창을 리사이즈할 수 있는지 판정 (비-Office는 첫 새 창 하나만 허용).
    /// Office는 grace 동안 새 문서창이 나타나면 이전 리사이즈를 교체할 수 있다.
    static func canResizeNewWindow(
        isMicrosoftOffice: Bool,
        alreadyResized: Bool
    ) -> Bool {
        isMicrosoftOffice || !alreadyResized
    }

    // MARK: - Observation loop

    /// AXObserver로 윈도우 생성을 구독하고, baseline 대비 새 창 하나를 리사이즈.
    /// 옵저버 생성이 실패하면 같은 루프를 usleep 폴링으로 수행한다 (관찰 로직 공용).
    static func observeAndResizeOneWindow(
        pid: pid_t, position: CGPoint, size: CGSize, startTime: CFAbsoluteTime,
        policy: ResizeObservationPolicy, debugLabel: String, observationKey: String,
        observationToken: Int, windowsBefore: [AXUIElement]
    ) -> ResizeObservationResult {
        let app = LauncherUtils.axApplication(pid: pid)
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
            if shouldAttemptEarlyFocusedFallback(
                didResize: ctx.didResize,
                didAttemptAlready: ctx.didAttemptEarlyFocusedFallback,
                elapsed: elapsed,
                focusedFallbackDelay: ctx.policy.focusedFallbackDelay)
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
            if isGracePeriodExpired(
                lastResizeTime: ctx.lastResizeTime,
                now: CFAbsoluteTimeGetCurrent(),
                postResizeGrace: ctx.policy.postResizeGrace)
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
