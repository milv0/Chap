import Cocoa

/// macOS 앱을 실행하고 System Events AppleScript로 윈도우를 리사이즈하는 런처
enum AppLauncher {
    /// 앱을 실행하고 윈도우 크기/위치를 조정
    /// - Parameters:
    ///   - site: 실행할 사이트 정보 (앱 경로, 크기 등)
    ///   - resizeQueue: 리사이즈 작업을 실행할 백그라운드 큐
    static func launch(_ site: Site, resizeQueue: DispatchQueue, onComplete: (() -> Void)? = nil) {
        // 앱 경로 유효성 검증
        guard let path = site.appPath, !path.isEmpty else {
            LauncherUtils.showAlert(message: "No app path configured for \"\(site.name)\".")
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            LauncherUtils.showAlert(message: "App not found at: \(path)")
            return
        }

        // Bundle에서 프로세스 이름 추출
        // 예: "Visual Studio Code.app" → CFBundleName = "Code"
        // .app 파일명과 실제 프로세스명이 다른 경우가 많아서 Info.plist에서 읽음
        let bundle = Bundle(path: path)
        let bundleId = bundle?.bundleIdentifier
        let processName =
            bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        // 대상 화면의 중앙 좌표 계산
        let screen = targetScreen(for: site)
        let bounds = centeredBounds(for: site, on: screen)
        let bw = site.width
        let bh = site.height

        NSLog(
            "[AppLauncher] launch site=%@ path=%@ bundleId=%@ processName=%@",
            site.name, path, bundleId ?? "nil", processName)
        NSLog(
            "[AppLauncher] target screen=%@ bounds={left:%d, top:%d, w:%d, h:%d}",
            screen.localizedName, bounds.left, bounds.top, bw, bh)

        // 접근성 권한 확인 — 없으면 앱만 실행하고 리사이즈는 스킵
        let canResize = checkAccessibility()
        if !canResize {
            NSLog("[AppLauncher] Accessibility not granted — launching without resize")
        }

        // AppleScript: 앱 활성화 명령 (bundle ID 우선, 없으면 프로세스명으로)
        let activateClause: String
        if let id = bundleId {
            activateClause = "tell application id \"\(id)\" to activate"
        } else {
            activateClause = "tell application \"\(processName)\" to activate"
        }

        // AppleScript: 앱 활성화 → System Events로 윈도우 찾기 → 크기/위치 설정
        // position을 두 번 설정하는 이유: size 변경 시 macOS가 position을 재조정할 수 있어서
        let appleScript = """
            \(activateClause)
            delay 0.05
            tell application "System Events"
                tell process "\(processName)"
                    repeat 30 times
                        if (count of windows) > 0 then
                            set position of front window to {\(bounds.left), \(bounds.top)}
                            set size of front window to {\(bw), \(bh)}
                            delay 0.05
                            set position of front window to {\(bounds.left), \(bounds.top)}
                            return
                        end if
                        delay 0.3
                    end repeat
                end tell
            end tell
            """

        // NSWorkspace로 앱 실행 (활성화 모드)
        // 앱이 이미 실행 중인지 여기서 확인 (콜백 안에서는 항상 true가 됨)
        let appRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleId
        }
        let delays: [Double] = appRunning ? [0.2, 0.5, 0.8, 1.2, 2.0] : [1.0, 2.0, 3.5, 5.0]

        let appURL = URL(fileURLWithPath: path)
        let openConfig = NSWorkspace.OpenConfiguration()
        openConfig.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { app, error in
            if let error = error {
                NSLog("[AppLauncher] openApplication failed: %@", error.localizedDescription)
                onComplete?()
                return
            }
            NSLog(
                "[AppLauncher] app opened pid=%d localizedName=%@",
                app?.processIdentifier ?? -1, app?.localizedName ?? "?")

            guard canResize else {
                onComplete?()
                return
            }

            LauncherUtils.retryResize(
                script: appleScript, delays: delays, queue: resizeQueue, label: site.name,
                type: "app", appState: appRunning ? "running" : "cold", windowCount: 0,
                display: screen.localizedName, size: "\(site.width)x\(site.height)",
                onComplete: onComplete)
        }
    }

    // MARK: - 접근성 권한

    private static var accessibilityPromptShown = false

    /// 접근성 권한 확인. 최초 1회만 시스템 다이얼로그로 권한 요청
    private static func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted { return true }
        if !accessibilityPromptShown {
            accessibilityPromptShown = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return false
    }
}
