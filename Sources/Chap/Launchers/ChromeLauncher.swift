import Cocoa

/// Chrome --app 모드로 URL을 열고 윈도우 크기를 조정하는 런처
enum ChromeLauncher {
    /// 사이트를 Chrome --app 모드로 실행하고, AppleScript로 윈도우 리사이즈
    /// - Parameters:
    ///   - site: 실행할 사이트 정보 (URL, 크기 등)
    ///   - resizeQueue: 리사이즈 작업을 실행할 백그라운드 큐
    static func launch(_ site: Site, resizeQueue: DispatchQueue) {
        // Chrome 설치 여부 확인
        guard FileManager.default.fileExists(atPath: "/Applications/Google Chrome.app") else {
            LauncherUtils.showAlert(message: "Google Chrome is not installed.")
            return
        }

        // URL에서 도메인 추출 및 유효성 검증 (인젝션 방지)
        let rawDomain = URL(string: site.url)?.host ?? ""
        guard isValidDomain(rawDomain) else {
            NSLog("[Chap] Invalid domain: %@", rawDomain)
            return
        }

        // 대상 화면의 중앙 좌표 계산 (NSScreen → AppleScript 좌표 변환 포함)
        let screen = targetScreen(for: site)
        let bounds = centeredBounds(for: site, on: screen)
        let boundsStr = "\(bounds.left), \(bounds.top), \(bounds.right), \(bounds.bottom)"

        // AppleScript: 도메인 매칭 윈도우를 한번 찾아 리사이즈. 못 찾으면 front window fallback.
        // 내부 retry 없음 — 외부 retryResize가 재시도 관리.
        let appleScript = """
        tell application "Google Chrome"
          repeat with w in windows
            if URL of active tab of w contains "\(rawDomain)" then
              set bounds of w to {\(boundsStr)}
              return "matched"
            end if
          end repeat
          if (count of windows) > 0 then
            set bounds of front window to {\(boundsStr)}
            return "fallback"
          end if
          return "no windows"
        end tell
        """

        // Chrome이 이미 실행 중인지 확인 (딜레이 결정에 사용)
        let chromeRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.google.Chrome"
        }
        NSLog("[Chap] Chrome launch for %@ — chromeRunning=%d", site.name, chromeRunning ? 1 : 0)

        // Chrome을 --app 모드로 실행 (주소바 없는 독립 윈도우)
        let openTask = Process()
        openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openTask.arguments = ["-na", "Google Chrome", "--args", "--app=\(site.url)"]
        do {
            try openTask.run()
        } catch {
            LauncherUtils.showAlert(message: "Failed to launch Chrome.", info: error.localizedDescription)
            return
        }

        // 윈도우가 뜰 때까지 점진적 딜레이 후 리사이즈 시도
        // 이미 실행 중이면 짧은 딜레이, 콜드 스타트면 긴 딜레이
        let delays: [Double] = chromeRunning ? [0.5, 0.8, 1.2, 2.0] : [1.0, 2.0, 3.5, 5.0]
        let windowCount = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.google.Chrome" }.count
        let displayName = screen.localizedName
        let sizeStr = "\(site.width)x\(site.height)"
        LauncherUtils.retryResize(script: appleScript, delays: delays, queue: resizeQueue, label: site.name, type: "url", appState: chromeRunning ? "running" : "cold", windowCount: windowCount, display: displayName, size: sizeStr)
    }
}
