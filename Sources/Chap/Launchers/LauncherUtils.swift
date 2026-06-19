import Cocoa

/// 런처들이 공통으로 사용하는 유틸리티
enum LauncherUtils {
    /// 에러 알림 표시 (메인 스레드에서 실행)
    static func showAlert(message: String, info: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            if let info = info { alert.informativeText = info }
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// AppleScript를 점진적 딜레이로 반복 실행하여 윈도우 리사이즈 시도
    /// - Parameters:
    ///   - script: 실행할 AppleScript 문자열
    ///   - delays: 시도 간 대기 시간 배열
    ///   - queue: 실행할 백그라운드 큐
    ///   - label: 실패 시 로그에 표시할 식별자
    static func retryResize(script: String, delays: [Double], queue: DispatchQueue, label: String, type: String = "url", appState: String = "unknown", windowCount: Int = 0, display: String = "", size: String = "") {
        queue.async {
            let startTime = CFAbsoluteTimeGetCurrent()
            NSLog("[Chap] resize start for %@ (type=%@, state=%@)", label, type, appState)
            for (attempt, d) in delays.enumerated() {
                Thread.sleep(forTimeInterval: d)
                let task = Process()
                let pipe = Pipe()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                task.arguments = ["-e", script]
                task.standardError = pipe
                task.standardOutput = pipe
                do {
                    try task.run()
                    task.waitUntilExit()
                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                    if task.terminationStatus == 0 {
                        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        NSLog("[Chap] resize success for %@ — attempt %d, delay %.1fs, total %.2fs, output=%@", label, attempt + 1, d, elapsed, output)
                        ResizeLogger.log(site: label, type: type, appState: appState, attempt: attempt + 1, delay: d, totalTime: elapsed, result: "success", windowCount: windowCount, display: display, size: size)
                        return
                    }
                    let errMsg = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    NSLog("[Chap] resize attempt %d failed for %@ (status=%d, error=%@, total %.2fs)", attempt + 1, label, task.terminationStatus, errMsg, elapsed)
                } catch {
                    NSLog("[Chap] resize attempt %d error for %@: %@", attempt + 1, label, error.localizedDescription)
                    continue
                }
            }
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            NSLog("[Chap] All resize attempts failed for %@ — total %.2fs", label, totalTime)
            ResizeLogger.log(site: label, type: type, appState: appState, attempt: delays.count, delay: delays.last ?? 0, totalTime: totalTime, result: "failed", windowCount: windowCount, display: display, size: size)
        }
    }
}
