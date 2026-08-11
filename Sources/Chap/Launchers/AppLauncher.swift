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
    private static let microsoftOfficeBundleIds: Set<String> = [
        "com.microsoft.Powerpoint",
        "com.microsoft.Excel",
        "com.microsoft.Word",
        "com.microsoft.onenote.mac",
    ]

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
