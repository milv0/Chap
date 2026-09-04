import ApplicationServices
import Cocoa
import os

struct ChromePIDTransition: Equatable {
    let fromPID: pid_t
    let toPID: pid_t
    let elapsedSinceLaunch: TimeInterval
}

struct ChromeLaunchTiming: Equatable {
    let baselineDuration: TimeInterval
    let launchRequestDuration: TimeInterval
    let windowWaitDuration: TimeInterval
    let boundsApplyDuration: TimeInterval
    let baselinePID: pid_t
    let pidTransitions: [ChromePIDTransition]

    var diagnostic: String {
        let firstTransition = pidTransitions.first?.elapsedSinceLaunch
        let baselineReturn =
            pidTransitions
            .dropFirst()
            .first { $0.toPID == baselinePID }?
            .elapsedSinceLaunch
        let pidPath = ([baselinePID] + pidTransitions.map(\.toPID))
            .map { $0 < 0 ? "none" : String($0) }
            .joined(separator: ">")

        return
            "timing baseline=\(seconds(baselineDuration))s"
            + " launch=\(seconds(launchRequestDuration))s"
            + " window_wait=\(seconds(windowWaitDuration))s"
            + " ax=\(seconds(boundsApplyDuration))s"
            + " pid_switches=\(pidTransitions.count)"
            + " first_pid_event=\(optionalSeconds(firstTransition))"
            + " baseline_pid_return=\(optionalSeconds(baselineReturn))"
            + " pid_path=\(pidPath)"
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func optionalSeconds(_ value: TimeInterval?) -> String {
        guard let value else { return "na" }
        return "\(seconds(value))s"
    }
}

enum ChromeWindowReuseScriptResult: Equatable {
    case matched(windowID: Int)
    case notFound
    case invalidOutput
}

/// Chrome --app 모드로 URL을 열고 AX API로 윈도우 크기를 조정하는 런처
///
/// 모든 Chrome launch 요청은 단일 serial queue(requestCoordinator)에서 직렬 처리된다:
/// baseline capture → Process launch → poll for new window → resize.
/// 이렇게 하면 빠르게 연속 실행해도 요청-창 1:1 대응이 보장된다.
enum ChromeLauncher {
    private static let appPath = "/Applications/Google Chrome.app"
    private static let bundleID = "com.google.Chrome"
    private static let appName = "Google Chrome"
    private static let runtime = ChromeRuntime.live
    private static let diagnosticQueue = DispatchQueue(
        label: "com.mingyupark.Chap.ChromeDiagnostics", qos: .utility)
    private static var didShowChromeAutomationAlert = false
    private static var trackedWindows: [UUID: TrackedChromeWindow] = [:]

    /// 단일 request coordinator serial queue.
    /// Process launch도 이 큐 안에서 수행하여 요청-창 1:1 순서를 보장한다.
    private static let requestCoordinator = DispatchQueue(
        label: "com.mingyupark.Chap.ChromeRequestCoordinator",
        qos: .userInitiated
    )

    /// 여러 Chrome 런치가 겹칠 때 같은 새 창을 두 런치가 붙잡는 오배정을 방어적으로 막는다.
    /// requestCoordinator가 직렬화하지만, 방어적으로 유지.
    private static let claimedWindows = ClaimedWindowRegistry()

    private struct WindowResizeObservation {
        let result: AXBoundsResult?
        let windowWaitDuration: TimeInterval
        let boundsApplyDuration: TimeInterval
        let pidTransitions: [ChromePIDTransition]
    }

    private struct TrackedChromeWindow {
        let windowID: Int
        let url: String
        let processPID: pid_t
        let processLaunchDate: Date
    }

    private enum ExistingWindowReuseOutcome {
        case reused
        case notFound
        case unavailable(String)
    }

    private final class ClaimedWindowRegistry {
        private let lock = NSLock()
        private var claimed: [AXUIElement] = []

        /// candidates(새 창 후보) 중 아직 claim되지 않은 첫 창을 claim해 반환.
        /// liveWindows에 더 이상 없는(닫힌) 창은 정리해 레지스트리 무한 증가를 막는다.
        func claimFirstUnclaimed(from candidates: [AXUIElement], liveWindows: [AXUIElement])
            -> AXUIElement?
        {
            lock.lock()
            defer { lock.unlock() }
            claimed.removeAll { existing in
                !liveWindows.contains { CFEqual($0, existing) }
            }
            for window in candidates where !claimed.contains(where: { CFEqual($0, window) }) {
                claimed.append(window)
                return window
            }
            return nil
        }
    }

    /// Chrome을 --app 모드로 실행 (open -na)
    private static func runChromeApp(url: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-na", appName, "--args", "--app=\(url)"]
        try task.run()
    }

    static func configureWindowReuse(sites: [Site]) {
        var enabledURLs: [UUID: String] = [:]
        for site in sites where site.launchType == .url && site.reuseExistingWindow {
            enabledURLs[site.id] = site.url.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        requestCoordinator.async {
            trackedWindows = trackedWindows.filter { entry in
                enabledURLs[entry.key] == entry.value.url
            }
        }
    }

    /// 사이트를 Chrome --app 모드로 실행하고, AX API로 윈도우 리사이즈.
    ///
    static func launch(_ site: Site, onComplete: (() -> Void)? = nil) {
        guard FileManager.default.fileExists(atPath: appPath) else {
            Log.launcher.error("Google Chrome is not installed at \(appPath, privacy: .public)")
            LauncherUtils.showAlert(message: "Google Chrome is not installed.")
            onComplete?()
            return
        }

        let trimmedURL = site.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard launchURLHost(trimmedURL) != nil else {
            Log.launcher.error("Invalid URL: \(site.url, privacy: .private)")
            LauncherUtils.showAlert(
                message: "Invalid URL for \"\(site.name)\".",
                info: "URL을 확인해주세요: \(site.url)")
            onComplete?()
            return
        }

        guard let screen = targetScreen(for: site) else {
            Log.launcher.info("No display available — queueing Chrome without resize")
            requestCoordinator.async {
                do {
                    try runChromeApp(url: trimmedURL)
                } catch {
                    Log.launcher.error(
                        "Failed to launch Chrome: \(error.localizedDescription, privacy: .public)")
                    LauncherUtils.showAlert(
                        message: "Failed to launch Chrome.", info: error.localizedDescription)
                }
                onComplete?()
            }
            return
        }
        let bounds = centeredBounds(for: site, on: screen)

        let position = CGPoint(x: bounds.left, y: bounds.top)
        let size = CGSize(
            width: bounds.right - bounds.left, height: bounds.bottom - bounds.top)
        let screenName = screen.localizedName
        let siteName = site.name
        let siteUrl = trimmedURL
        let shouldReuseExistingWindow = site.reuseExistingWindow
        let sizeLabel = "\(bounds.right - bounds.left)x\(bounds.bottom - bounds.top)"

        // 모든 작업을 requestCoordinator serial queue에서 직렬 처리 (I4)
        let enqueuedAt = CFAbsoluteTimeGetCurrent()
        requestCoordinator.async {
            let startTime = CFAbsoluteTimeGetCurrent()
            let queueWait = startTime - enqueuedAt
            Log.launcher.info(
                "Chrome coordinator dequeued \(siteName, privacy: .private) after \(queueWait, format: .fixed(precision: 2))s"
            )

            if shouldReuseExistingWindow,
                reuseTrackedWindow(
                    site: site, siteName: siteName, siteUrl: siteUrl,
                    position: position, size: size,
                    screenName: screenName, sizeLabel: sizeLabel,
                    startTime: startTime)
            {
                onComplete?()
                return
            }

            // 1. Baseline: 실행 전 Chrome 윈도우 집합 기록 (I1/I3)
            let baseline = captureLaunchBaseline(
                shouldReuseExistingWindow: shouldReuseExistingWindow)
            Log.launcher.info(
                "Chrome coordinator: launch for \(siteName, privacy: .private) — running=\(baseline.running), windowsBefore=\(baseline.windowsBefore.count)"
            )

            // 2. Process launch (큐 안에서 수행, I4)
            guard let launchTiming = launchChromeProcess(url: siteUrl) else {
                onComplete?()
                return
            }

            guard AccessibilityPermission.isTrusted else {
                Log.launcher.info("Accessibility not granted — launching without resize")
                onComplete?()
                return
            }

            // 3. Poll + Resize
            let observation = axResizeNewWindow(
                baselinePid: baseline.pid,
                windowsBefore: baseline.windowsBefore,
                position: position,
                size: size,
                chromeRunning: baseline.running,
                launchCompletedAt: launchTiming.completedAt,
                runtime: runtime
            )
            if shouldReuseExistingWindow, observation.result != nil {
                rememberCreatedChromeWindow(
                    for: site.id,
                    url: siteUrl,
                    windowIDsBefore: baseline.windowIDsBefore,
                    sessionProcess: baseline.process,
                    runtime: runtime)
            }
            reportLaunchOutcome(
                observation: observation,
                baseline: baseline,
                launchRequestDuration: launchTiming.duration,
                siteName: siteName,
                screenName: screenName,
                sizeLabel: sizeLabel,
                queueWait: queueWait,
                startTime: startTime)
            onComplete?()
        }
    }

    // MARK: - Launch phases (requestCoordinator 큐 안에서만 호출)

    /// 세션에 기억된 Chap 소유 창 재사용을 시도한다 (§7.1.1, I14).
    /// 재사용에 성공해 실행을 끝냈으면 true, 새 창 흐름으로 폴백해야 하면 false.
    private static func reuseTrackedWindow(
        site: Site,
        siteName: String,
        siteUrl: String,
        position: CGPoint,
        size: CGSize,
        screenName: String,
        sizeLabel: String,
        startTime: CFAbsoluteTime
    ) -> Bool {
        switch reuseExistingWindow(
            siteID: site.id,
            url: siteUrl,
            position: position,
            size: size,
            runtime: runtime
        ) {
        case .reused:
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            let resultLabel = "applescript"
            let detail = "reused existing URL window by Chrome window ID"
            Log.launcher.notice(
                "Reused Chrome window for \(siteName, privacy: .private) — result=\(resultLabel, privacy: .public)"
            )
            ResizeLogger.log(
                site: siteName, type: "url",
                appState: "running",
                attempt: 1, delay: 0,
                totalTime: processingTime,
                result: resultLabel,
                windowCount: currentChromeProcess(runtime: runtime).map {
                    runtime.windows($0.pid).count
                } ?? 0,
                display: screenName,
                size: sizeLabel,
                detail: detail)
            return true
        case .notFound:
            Log.launcher.info(
                "No Chap-managed Chrome window for \(siteName, privacy: .private); opening a new window"
            )
            return false
        case .unavailable(let detail):
            Log.launcher.warning(
                "Chrome URL window reuse unavailable for \(siteName, privacy: .private); opening a new window — \(detail, privacy: .private)"
            )
            return false
        }
    }

    /// 실행 전 스냅샷. windowsBefore가 새 창 판별의 baseline이고(I1/I3),
    /// windowIDsBefore는 재사용 연결용 Chrome window ID 차집합의 기준이다.
    private struct ChromeLaunchBaseline {
        let process: ChromeProcessCandidate?
        let windowsBefore: [AXUIElement]
        let windowIDsBefore: Set<Int>?
        let duration: TimeInterval

        var running: Bool { process != nil }
        var pid: pid_t { process?.pid ?? -1 }
    }

    /// 1단계 — 실행 전 Chrome 프로세스·AX 창 집합·(재사용 시) window ID를 기록한다.
    private static func captureLaunchBaseline(
        shouldReuseExistingWindow: Bool
    ) -> ChromeLaunchBaseline {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let chromeProcess = currentChromeProcess(runtime: runtime)
        let chromeRunning = chromeProcess != nil
        let chromePid = chromeProcess?.pid ?? -1
        let windowsBefore =
            chromeRunning
            ? captureExistingWindows(pid: chromePid, runtime: runtime)
            : []
        let chromeWindowIDsBefore: Set<Int>? =
            shouldReuseExistingWindow
            ? (chromeRunning ? captureChromeWindowIDs() : [])
            : nil
        return ChromeLaunchBaseline(
            process: chromeProcess,
            windowsBefore: windowsBefore,
            windowIDsBefore: chromeWindowIDsBefore,
            duration: CFAbsoluteTimeGetCurrent() - startedAt)
    }

    /// 2단계 — Chrome 프로세스를 큐 안에서 실행한다 (I4).
    /// 실패 시 에러 로그와 메인 스레드 alert까지 처리하고 nil을 반환한다.
    private static func launchChromeProcess(
        url: String
    ) -> (completedAt: CFAbsoluteTime, duration: TimeInterval)? {
        let launchStartedAt = CFAbsoluteTimeGetCurrent()
        do {
            try runChromeApp(url: url)
        } catch {
            Log.launcher.error(
                "Failed to launch Chrome: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                LauncherUtils.showAlert(
                    message: "Failed to launch Chrome.", info: error.localizedDescription)
            }
            return nil
        }
        let launchCompletedAt = CFAbsoluteTimeGetCurrent()
        return (launchCompletedAt, launchCompletedAt - launchStartedAt)
    }

    /// 관찰 결과를 단계별 timing·레벨별 통합 로그·리사이즈 CSV(I8)로 남긴다.
    /// 성공 판정은 readback 기반 AXBoundsResult(I2)를 그대로 사용하며,
    /// 실패 시 Chrome 비응답(자동 업데이트 재시작 대기)을 접근성 실패와 구분한다.
    private static func reportLaunchOutcome(
        observation: WindowResizeObservation,
        baseline: ChromeLaunchBaseline,
        launchRequestDuration: TimeInterval,
        siteName: String,
        screenName: String,
        sizeLabel: String,
        queueWait: TimeInterval,
        startTime: CFAbsoluteTime
    ) {
        let result = observation.result
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let resultLabel = result?.level.rawValue ?? "failed"
        let timing = ChromeLaunchTiming(
            baselineDuration: baseline.duration,
            launchRequestDuration: launchRequestDuration,
            windowWaitDuration: observation.windowWaitDuration,
            boundsApplyDuration: observation.boundsApplyDuration,
            baselinePID: baseline.pid,
            pidTransitions: observation.pidTransitions)
        let timingDiagnostic = timing.diagnostic
        let resultDetail = result?.diagnostic ?? "no new window found"
        let detail = "\(resultDetail) | \(timingDiagnostic)"
        Log.launcher.info(
            "Chrome stage timing for \(siteName, privacy: .private) — \(timingDiagnostic, privacy: .public)"
        )
        if let result {
            switch result.level {
            case .fullyApplied:
                Log.launcher.notice(
                    "Chrome AX resize verified for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s"
                )
            case .partiallyApplied:
                Log.launcher.warning(
                    "Chrome AX resize partially applied for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                )
            case .failed:
                Log.launcher.error(
                    "Chrome AX resize verification failed for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s \(detail, privacy: .public)"
                )
                AccessibilityPermission.notifyResizeFailure()
            }
        } else {
            Log.launcher.error(
                "Chrome AX resize failed for \(siteName, privacy: .private) — processing=\(processingTime, format: .fixed(precision: 2))s queue=\(queueWait, format: .fixed(precision: 2))s \(detail, privacy: .public)"
            )
            // Chrome이 실행 중이라는데 baseline 창이 0개이고 새 창도 못 잡았다면,
            // 보통 Chrome이 자동 업데이트된 뒤 재시작을 기다리며 AX에 응답하지 않는
            // 상태다. 접근성 실패로 오인시키지 말고 재시작을 안내한다.
            if chromeAppearsUnresponsive(
                chromeRunning: baseline.running,
                baselineWindowCount: baseline.windowsBefore.count,
                foundNewWindow: false)
            {
                scheduleChromeUnresponsiveNotice(
                    pid: currentChromeProcess(runtime: runtime)?.pid)
            } else {
                AccessibilityPermission.notifyResizeFailure()
            }
        }
        ResizeLogger.log(
            site: siteName, type: "url",
            appState: baseline.running ? "running" : "cold",
            attempt: 1, delay: 0,
            totalTime: processingTime,
            result: resultLabel,
            windowCount: baseline.windowsBefore.count,
            display: screenName,
            size: sizeLabel,
            detail: detail)
    }

    // MARK: - AX API Resize

    private static func currentChromeProcess(runtime: ChromeRuntime) -> ChromeProcessCandidate? {
        ChromeObservationPolicy.currentProcess(from: runtime.processes(bundleID))
    }

    private static func captureExistingWindows(pid: pid_t, runtime: ChromeRuntime)
        -> [AXUIElement]
    {
        for attempt in 0..<5 {
            let windows = runtime.windows(pid)
            if !windows.isEmpty { return windows }
            if attempt < 4 { runtime.sleep(30_000) }
        }
        return []
    }

    // MARK: - Existing URL Window Reuse

    private static func reuseExistingWindow(
        siteID: UUID, url: String, position: CGPoint, size: CGSize, runtime: ChromeRuntime
    ) -> ExistingWindowReuseOutcome {
        guard let trackedWindow = trackedWindows[siteID], trackedWindow.url == url else {
            trackedWindows[siteID] = nil
            return .notFound
        }
        let currentProcess = currentChromeProcess(runtime: runtime)
        let isSameChromeSession =
            currentProcess?.pid == trackedWindow.processPID
            && currentProcess?.launchDate == trackedWindow.processLaunchDate
        guard isSameChromeSession else {
            trackedWindows[siteID] = nil
            return .notFound
        }

        switch runChromeWindowScript(
            trackedWindowScript(windowID: trackedWindow.windowID)
        ) {
        case .result(.matched):
            let outcome = resizeChromeWindow(
                windowID: trackedWindow.windowID,
                position: position,
                size: size
            )
            if case .notFound = outcome {
                trackedWindows[siteID] = nil
            }
            return outcome
        case .result(.notFound):
            trackedWindows[siteID] = nil
            return .notFound
        case .result(.invalidOutput):
            return .unavailable("Chrome returned an invalid tracked-window response")
        case .unavailable(let detail):
            return .unavailable(detail)
        }
    }

    private static func resizeChromeWindow(
        windowID: Int, position: CGPoint, size: CGSize
    ) -> ExistingWindowReuseOutcome {
        switch runChromeWindowScript(
            resizeWindowScript(windowID: windowID, position: position, size: size)
        ) {
        case .result(.matched):
            return .reused
        case .result(.notFound):
            return .notFound
        case .result(.invalidOutput):
            return .unavailable("Chrome returned an invalid resize response")
        case .unavailable(let detail):
            return .unavailable(detail)
        }
    }

    private static func runChromeScript(_ source: String) -> ChromeScriptOutcome {
        guard let script = NSAppleScript(source: source) else {
            return .unavailable("Could not create Chrome automation script")
        }
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if let error {
            let errorNumber = (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue
            if errorNumber == -1743 {
                showChromeAutomationPermissionAlert()
                return .unavailable("Chrome automation permission denied")
            }
            let errorMessage = error[NSAppleScript.errorMessage] as? String
            return .unavailable(errorMessage ?? "Chrome automation failed")
        }

        return .output(output.stringValue ?? "")
    }

    private static func runChromeWindowScript(_ source: String) -> ChromeWindowScriptOutcome {
        switch runChromeScript(source) {
        case .output(let output):
            return .result(parseExistingWindowScriptOutput(output))
        case .unavailable(let detail):
            return .unavailable(detail)
        }
    }

    private static func captureChromeWindowIDs() -> Set<Int>? {
        switch runChromeScript(windowIDsScript()) {
        case .output(let output):
            return parseWindowIDsScriptOutput(output)
        case .unavailable(let detail):
            Log.launcher.warning(
                "Could not capture Chrome window IDs — \(detail, privacy: .private)")
            return nil
        }
    }

    private static func rememberCreatedChromeWindow(
        for siteID: UUID,
        url: String,
        windowIDsBefore: Set<Int>?,
        sessionProcess: ChromeProcessCandidate?,
        runtime: ChromeRuntime
    ) {
        guard let windowIDsBefore else {
            Log.launcher.warning(
                "Skipped Chrome window tracking because the pre-launch ID snapshot was unavailable")
            return
        }
        guard let process = sessionProcess ?? currentChromeProcess(runtime: runtime) else {
            return
        }

        for attempt in 0..<5 {
            guard let windowIDsAfter = captureChromeWindowIDs() else { return }
            let createdWindowIDs = windowIDsAfter.subtracting(windowIDsBefore)
            if let windowID = createdChromeWindowID(
                before: windowIDsBefore, after: windowIDsAfter)
            {
                trackedWindows[siteID] = TrackedChromeWindow(
                    windowID: windowID,
                    url: url,
                    processPID: process.pid,
                    processLaunchDate: process.launchDate)
                Log.launcher.info(
                    "Remembered Chap-created Chrome window id=\(windowID, privacy: .public)")
                return
            }
            if createdWindowIDs.count > 1 {
                Log.launcher.warning(
                    "Skipped Chrome window tracking because \(createdWindowIDs.count, privacy: .public) new window IDs were observed"
                )
                return
            }
            if attempt < 4 { runtime.sleep(50_000) }
        }
        Log.launcher.warning(
            "Skipped Chrome window tracking because no new Chrome window ID was observed")
    }

    static func trackedWindowScript(windowID: Int) -> String {
        """
        with timeout of 3 seconds
            tell application "Google Chrome"
                try
                    set chromeWindow to first window whose id is \(windowID)
                    set index of chromeWindow to 1
                    activate
                    delay 0.25
                    return "matched:" & ((id of chromeWindow) as text)
                on error number -1728
                    return "not-found"
                end try
            end tell
        end timeout
        """
    }

    static func resizeWindowScript(windowID: Int, position: CGPoint, size: CGSize) -> String {
        let left = Int(position.x.rounded())
        let top = Int(position.y.rounded())
        let right = left + Int(size.width.rounded())
        let bottom = top + Int(size.height.rounded())
        return """
            with timeout of 3 seconds
                tell application "Google Chrome"
                    try
                        set chromeWindow to first window whose id is \(windowID)
                        set bounds of chromeWindow to {\(left), \(top), \(right), \(bottom)}
                        return "matched:" & ((id of chromeWindow) as text)
                    on error number -1728
                        return "not-found"
                    end try
                end tell
            end timeout
            """
    }

    static func windowIDsScript() -> String {
        """
        with timeout of 3 seconds
            tell application "Google Chrome"
                set windowIDs to {}
                repeat with chromeWindow in windows
                    set end of windowIDs to ((id of chromeWindow) as text)
                end repeat
                set previousDelimiters to AppleScript's text item delimiters
                set AppleScript's text item delimiters to ","
                set resultText to windowIDs as text
                set AppleScript's text item delimiters to previousDelimiters
                return "ids:" & resultText
            end tell
        end timeout
        """
    }

    static func parseWindowIDsScriptOutput(_ output: String) -> Set<Int>? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("ids:") else { return nil }
        let payload = String(trimmed.dropFirst(4))
        guard !payload.isEmpty else { return [] }

        let components = payload.split(
            separator: ",", omittingEmptySubsequences: false)
        var windowIDs = Set<Int>()
        for component in components {
            guard let windowID = Int(component), windowID > 0 else { return nil }
            windowIDs.insert(windowID)
        }
        return windowIDs.count == components.count ? windowIDs : nil
    }

    static func createdChromeWindowID(before: Set<Int>, after: Set<Int>) -> Int? {
        let createdWindowIDs = after.subtracting(before)
        guard createdWindowIDs.count == 1 else { return nil }
        return createdWindowIDs.first
    }

    static func parseExistingWindowScriptOutput(_ output: String)
        -> ChromeWindowReuseScriptResult
    {
        switch output.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "not-found":
            return .notFound
        default:
            let components =
                output
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":", maxSplits: 1)
            guard components.count == 2,
                components[0] == "matched",
                let windowID = Int(components[1]),
                windowID > 0
            else {
                return .invalidOutput
            }
            return .matched(windowID: windowID)
        }
    }

    private static func showChromeAutomationPermissionAlert() {
        guard !didShowChromeAutomationAlert else { return }
        didShowChromeAutomationAlert = true
        DispatchQueue.main.async {
            LauncherUtils.showAlert(
                message: "Allow Chap to control Google Chrome.",
                info: "Reuse Existing URL Window needs Automation permission. "
                    + "In System Settings > Privacy & Security > Automation, enable Google Chrome for Chap."
            )
        }
    }

    private enum ChromeWindowScriptOutcome {
        case result(ChromeWindowReuseScriptResult)
        case unavailable(String)
    }

    private enum ChromeScriptOutcome {
        case output(String)
        case unavailable(String)
    }

    /// 새 Chrome 창을 폴링해 찾고, 찾으면 리사이즈. AXBoundsResult를 반환 (못 찾으면 nil).
    /// pid가 바뀌면 이전 창 fingerprint의 multiset을 새 pid 창에서 차감하여 복원 창은
    /// baseline으로, 남는 창은 요청 후보로 취급한다. 따라서 pid 전환 직후 이미 생성된
    /// --app 창을 baseline에 흡수하는 race를 피한다.
    private static func axResizeNewWindow(
        baselinePid: pid_t, windowsBefore: [AXUIElement], position: CGPoint, size: CGSize,
        chromeRunning: Bool, launchCompletedAt: CFAbsoluteTime, runtime: ChromeRuntime
    ) -> WindowResizeObservation {
        let maxAttempts = chromeRunning ? 120 : 100
        let interval: useconds_t = chromeRunning ? 50_000 : 100_000
        let baselineFingerprints = windowsBefore.map(AXIntrospection.windowFingerprint)
        var baselineOwnerPid = baselinePid
        var didRelaunch = false
        var pidTransitions: [ChromePIDTransition] = []

        for _ in 0..<maxAttempts {
            guard let process = currentChromeProcess(runtime: runtime) else {
                runtime.sleep(interval)
                continue
            }
            let pid = process.pid
            if pid != baselineOwnerPid {
                pidTransitions.append(
                    ChromePIDTransition(
                        fromPID: baselineOwnerPid,
                        toPID: pid,
                        elapsedSinceLaunch: CFAbsoluteTimeGetCurrent() - launchCompletedAt))
                Log.launcher.info(
                    "Chrome pid changed \(baselineOwnerPid, privacy: .public) -> \(pid, privacy: .public); matching restored windows"
                )
                baselineOwnerPid = pid
                didRelaunch = true
            }

            let windows = runtime.windows(pid)
            let newWindows: [AXUIElement]
            if didRelaunch {
                let currentFingerprints = windows.map(AXIntrospection.windowFingerprint)
                let candidateIndices = ChromeObservationPolicy.candidateIndicesAfterRelaunch(
                    chromeWasRunning: chromeRunning,
                    baselineFingerprints: baselineFingerprints,
                    currentFingerprints: currentFingerprints)
                newWindows = candidateIndices.map { windows[$0] }
            } else {
                newWindows = windows.filter { win in
                    !windowsBefore.contains { CFEqual($0, win) }
                }
            }

            if let newWindow = claimedWindows.claimFirstUnclaimed(
                from: newWindows, liveWindows: windows)
            {
                let windowDetectedAt = CFAbsoluteTimeGetCurrent()
                let boundsResult = LauncherUtils.axApplyBounds(
                    newWindow, position: position, size: size)
                let boundsAppliedAt = CFAbsoluteTimeGetCurrent()
                Log.launcher.info(
                    "Chrome AX bounds applied: level=\(boundsResult.level.rawValue, privacy: .public) pos=\(boundsResult.positionWithinTolerance) size=\(boundsResult.sizeWithinTolerance)"
                )
                return WindowResizeObservation(
                    result: boundsResult,
                    windowWaitDuration: windowDetectedAt - launchCompletedAt,
                    boundsApplyDuration: boundsAppliedAt - windowDetectedAt,
                    pidTransitions: pidTransitions)
            }
            runtime.sleep(interval)
        }
        return WindowResizeObservation(
            result: nil,
            windowWaitDuration: CFAbsoluteTimeGetCurrent() - launchCompletedAt,
            boundsApplyDuration: 0,
            pidTransitions: pidTransitions)
    }

    // MARK: - Unresponsive Chrome detection

    /// Chrome이 실행 중(`chromeRunning`)이라고 보고되지만 baseline AX 창이 0개이고
    /// 새 창도 감지하지 못했다면, Chrome이 자동 업데이트 후 재시작 대기 등으로 AX에
    /// 응답하지 못하는 상태로 본다. 콜드 스타트(창 0개가 정상)나 창이 이미 있는 경우,
    /// 새 창을 찾은 경우는 제외한다.
    static func chromeAppearsUnresponsive(
        chromeRunning: Bool, baselineWindowCount: Int, foundNewWindow: Bool
    ) -> Bool {
        chromeRunning && baselineWindowCount == 0 && !foundNewWindow
    }

    /// 로드된 Chrome Framework dylib 경로에서 버전 문자열을 추출한다.
    /// 예: `.../Google Chrome Framework.framework/Versions/150.0.7871.189/Google Chrome Framework`
    /// → `150.0.7871.189`. 경로에 `Versions/` 세그먼트가 없으면 nil.
    static func frameworkVersion(fromLoadedPath path: String) -> String? {
        guard let range = path.range(of: "Google Chrome Framework.framework/Versions/") else {
            return nil
        }
        let version = path[range.upperBound...].prefix { $0 != "/" }
        return version.isEmpty ? nil : String(version)
    }

    /// 실행 중 프로세스가 로드한 버전과 디스크 번들 버전이 다르면, 업데이트가 설치됐지만
    /// 아직 relaunch되지 않은 상태다(현재 프로세스는 낡은 프레임워크를 계속 사용).
    /// 어느 한쪽이라도 알 수 없으면 판단하지 않는다(false).
    static func isPendingRelaunch(runningVersion: String?, diskVersion: String?) -> Bool {
        guard let running = runningVersion, let disk = diskVersion,
            !running.isEmpty, !disk.isEmpty
        else { return false }
        return running != disk
    }

    /// 디스크에 설치된 Chrome.app 번들 버전(CFBundleShortVersionString).
    private static func diskBundleVersion() -> String? {
        Bundle(path: appPath)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static func frameworkVersion(fromLsofOutput output: String) -> String? {
        for line in output.split(separator: "\n")
        where line.contains("Google Chrome Framework.framework/Versions/") {
            if let version = frameworkVersion(fromLoadedPath: String(line)) {
                return version
            }
        }
        return nil
    }

    /// lsof는 전용 diagnostics queue에서 실행되며 ProcessRunner가 timeout과 출력 상한을
    /// 강제한다. 진단 실패는 resize/launch 결과에 영향을 주지 않는다.
    private static func runningFrameworkVersion(pid: pid_t) -> String? {
        guard
            let result = try? ProcessRunner.run(
                executable: "/usr/sbin/lsof",
                arguments: ["-p", "\(pid)"],
                timeout: 2,
                outputLimit: 256 * 1024),
            !result.timedOut,
            result.exitStatus == 0
        else { return nil }
        return frameworkVersion(fromLsofOutput: result.stdoutString)
    }

    private static let restartNoticeLock = NSLock()
    private static var lastRestartNoticeAt: CFAbsoluteTime = 0
    private static let restartNoticeInterval: CFAbsoluteTime = 60

    private static func scheduleChromeUnresponsiveNotice(pid: pid_t?) {
        restartNoticeLock.lock()
        let now = CFAbsoluteTimeGetCurrent()
        let shouldShow = now - lastRestartNoticeAt >= restartNoticeInterval
        if shouldShow { lastRestartNoticeAt = now }
        restartNoticeLock.unlock()
        guard shouldShow else { return }

        diagnosticQueue.async {
            notifyChromeUnresponsive(pid: pid)
        }
    }

    private static func notifyChromeUnresponsive(pid: pid_t?) {
        let diskVersion = diskBundleVersion()
        let runningVersion = pid.flatMap { runningFrameworkVersion(pid: $0) }
        let pendingRelaunch = isPendingRelaunch(
            runningVersion: runningVersion, diskVersion: diskVersion)

        var info =
            "Chrome이 창 크기 조정 요청에 일시적으로 응답하지 않습니다. 편하실 때 주소창에 chrome://restart 를 입력하거나 우측 상단 ⋮ 메뉴에서 재실행하면(열려 있던 탭은 그대로 복원) Chap이 자동으로 인식해 정상화됩니다. 작업 중인 창을 닫을 필요는 없습니다."
        if pendingRelaunch, let runningVersion, let diskVersion {
            info =
                "Chrome 업데이트(\(diskVersion))가 설치됐지만 실행 중인 버전(\(runningVersion))이 아직 재실행되지 않아 창 크기 조정이 일시적으로 동작하지 않습니다.\n\n"
                + info
        }

        LauncherUtils.showAlert(message: "Chrome 업데이트 재실행 안내", info: info)
    }
}
