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
///
/// 관찰(observation) 루프/fallback/eligibility/logging 헬퍼는 `AppLauncher+Observation.swift`,
/// 관찰 정책/결과/레지스트리/컨텍스트 타입은 `AppLauncherSupport.swift`에 있다.
enum AppLauncher {
    static let observationRegistry = ResizeObservationRegistry()

    /// macOS가 실제 앱 식별에 쓰는 CFBundleIdentifier allowlist.
    ///
    /// `com.microsoft.` prefix로 판별하면 Teams/Outlook 같은 비대상 앱까지 걸릴 수 있다.
    /// 시작창 -> 문서창 전환이 잦은 문서형 Office 앱만 명시 목록으로 제한한다.
    /// PowerPoint의 ID는 제품명 표기와 다르게 `Powerpoint`가 맞다.
    static let microsoftOfficeBundleIds: Set<String> = [
        "com.microsoft.Powerpoint",
        "com.microsoft.Excel",
        "com.microsoft.Word",
        "com.microsoft.onenote.mac",
    ]

    /// 번들 ID가 문서형 Microsoft Office 앱인지 판정. Teams/Outlook은 제외된다.
    static func isMicrosoftOfficeApp(bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return microsoftOfficeBundleIds.contains(bundleId)
    }

    /// 앱을 실행하고 윈도우 크기/위치를 조정
    ///
    /// 단계: 경로 검증 → 대상 화면·bounds 결정 → 권한 확인 → baseline 캡처(I1/I3)
    /// → openApplication → 관찰·결과 보고. 각 단계는 아래 private 메서드로 분리돼 있다.
    static func launch(_ site: Site, onComplete: (() -> Void)? = nil) {
        guard let path = validatedAppPath(for: site) else {
            onComplete?()
            return
        }

        let bundleId = Bundle(path: path)?.bundleIdentifier

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

        let baseline = captureBaseline(bundleId: bundleId)

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
            observeAndReport(
                app: app, site: site, fallbackBundleId: bundleId, screen: screen,
                bounds: bounds, baseline: baseline, startTime: startTime,
                onComplete: onComplete)
        }
    }

    // MARK: - Launch phases

    /// appPath 필수값·존재 검증. 실패 시 에러 로그와 alert까지 처리하고 nil을 반환한다.
    private static func validatedAppPath(for site: Site) -> String? {
        guard let path = site.appPath, !path.isEmpty else {
            Log.launcher.error("No app path configured for \(site.name, privacy: .private)")
            LauncherUtils.showAlert(message: "No app path configured for \"\(site.name)\".")
            return nil
        }
        guard FileManager.default.fileExists(atPath: path) else {
            Log.launcher.error("App not found at: \(path, privacy: .private)")
            LauncherUtils.showAlert(message: "App not found at: \(path)")
            return nil
        }
        return path
    }

    /// 실행 전 스냅샷. windowsBefore는 새 창 판별의 baseline이다 (I1/I3).
    private struct LaunchBaseline {
        let appRunning: Bool
        let windowsBefore: [AXUIElement]
    }

    /// 앱 실행 여부와 실행 전 AX 윈도우 집합을 기록한다.
    private static func captureBaseline(bundleId: String?) -> LaunchBaseline {
        let runningApp = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleId
        }
        let windowsBefore: [AXUIElement]
        if let pid = runningApp?.processIdentifier {
            windowsBefore = LauncherUtils.captureExistingWindows(pid: pid)
        } else {
            windowsBefore = []
        }
        return LaunchBaseline(appRunning: runningApp != nil, windowsBefore: windowsBefore)
    }

    /// openApplication 성공 후: 관찰 정책·supersede 토큰(I10)을 준비하고,
    /// 전용 백그라운드 큐에서 새 창 관찰과 결과 보고를 수행한다.
    /// 관찰(run loop)이 길게 유지될 수 있으므로 전용 백그라운드 큐에서 실행해
    /// 다른 런처(Chrome 등)의 작업을 막지 않도록 한다.
    private static func observeAndReport(
        app: NSRunningApplication,
        site: Site,
        fallbackBundleId: String?,
        screen: NSScreen,
        bounds: (left: Int, top: Int, right: Int, bottom: Int),
        baseline: LaunchBaseline,
        startTime: CFAbsoluteTime,
        onComplete: (() -> Void)?
    ) {
        Log.launcher.info(
            "app opened pid=\(app.processIdentifier) localizedName=\(app.localizedName ?? "?", privacy: .private)"
        )

        let bw = bounds.right - bounds.left
        let bh = bounds.bottom - bounds.top
        let position = CGPoint(x: bounds.left, y: bounds.top)
        let size = CGSize(width: bw, height: bh)
        let policy = resizeObservationPolicy(
            bundleId: app.bundleIdentifier ?? fallbackBundleId,
            appRunning: baseline.appRunning
        )
        let observationKey =
            app.bundleIdentifier ?? fallbackBundleId ?? "pid:\(app.processIdentifier)"
        let observationToken = observationRegistry.begin(key: observationKey)
        if policy.isMicrosoftOffice {
            Log.launcher.info(
                "Microsoft Office observation policy for \(site.name, privacy: .private): timeout=\(policy.timeout, privacy: .public)s postResizeGrace=\(policy.postResizeGrace, privacy: .public)s focusedFallbackDelay=\(policy.focusedFallbackDelay, privacy: .public)s"
            )
        }

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
                windowsBefore: baseline.windowsBefore
            )
            if result.wasSuperseded {
                Log.launcher.info(
                    "AX observation superseded for \(site.name, privacy: .private)"
                )
                onComplete?()
                return
            }
            reportObservationResult(
                result, site: site,
                appState: baseline.appRunning ? "running" : "cold",
                baselineWindowCount: baseline.windowsBefore.count,
                displayName: screen.localizedName,
                sizeLabel: "\(bw)x\(bh)",
                startTime: startTime)
            onComplete?()
        }
    }

    /// 관찰 결과를 레벨별 통합 로그와 리사이즈 CSV(I8)로 남긴다.
    /// 성공 판정은 readback 기반 AXBoundsResult(I2)를 그대로 사용한다.
    private static func reportObservationResult(
        _ result: ResizeObservationResult,
        site: Site,
        appState: String,
        baselineWindowCount: Int,
        displayName: String,
        sizeLabel: String,
        startTime: CFAbsoluteTime
    ) {
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
            notifyMinimumSizeClampIfNeeded(boundsResult, siteName: site.name)
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
            appState: appState,
            attempt: 1, delay: 0,
            totalTime: latency,
            result: resultLabel,
            windowCount: baselineWindowCount,
            display: displayName,
            size: sizeLabel,
            detail: detail)
    }

    // MARK: - Minimum size notice

    private static let minimumSizeNoticeLock = NSLock()
    private static var shownMinimumSizeNoticeKeys: Set<String> = []

    /// 요청 크기가 앱 최소 크기보다 작아 클램프됐으면 원인을 사용자에게 안내한다.
    /// 같은 launchable·크기 조합은 앱 세션당 한 번만 표시한다 (FLOW.md 이슈 2 개선).
    private static func notifyMinimumSizeClampIfNeeded(
        _ boundsResult: AXBoundsResult, siteName: String
    ) {
        guard
            MinimumSizeNoticePolicy.shouldNotify(
                sizeApplied: boundsResult.sizeWithinTolerance,
                clampingMinimumSize: boundsResult.clampingMinimumSize),
            let minimumSize = boundsResult.clampingMinimumSize
        else { return }

        let key = MinimumSizeNoticePolicy.dedupeKey(
            siteName: siteName, requestedSize: boundsResult.requestedSize)
        minimumSizeNoticeLock.lock()
        let isFirstNotice = shownMinimumSizeNoticeKeys.insert(key).inserted
        minimumSizeNoticeLock.unlock()
        guard isFirstNotice else { return }

        Log.launcher.notice(
            "Minimum size notice for \(siteName, privacy: .private): requested=\(Int(boundsResult.requestedSize.width))x\(Int(boundsResult.requestedSize.height), privacy: .public) minimum=\(Int(minimumSize.width))x\(Int(minimumSize.height), privacy: .public)"
        )
        LauncherUtils.showAlert(
            message: MinimumSizeNoticePolicy.message(siteName: siteName),
            info: MinimumSizeNoticePolicy.info(
                minimumSize: minimumSize, requestedSize: boundsResult.requestedSize))
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

    static func resizeObservationPolicy(
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

    // MARK: - Bounds application

    /// 실제 bounds 적용 + 결과 기록
    @discardableResult
    static func applyBoundsToWindow(_ window: AXUIElement, ctx: ResizeContext)
        -> AXBoundsResult
    {
        Log.launcher.info(
            "AX applying bounds for \(ctx.debugLabel, privacy: .private): title=\(AXIntrospection.windowTitle(window), privacy: .private) id=\(AXIntrospection.windowNumber(window), privacy: .public) \(AXIntrospection.windowSummary(window), privacy: .public)"
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
}
