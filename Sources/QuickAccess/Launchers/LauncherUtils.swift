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
    static func retryResize(script: String, delays: [Double], queue: DispatchQueue, label: String) {
        queue.async {
            for d in delays {
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
                    if task.terminationStatus == 0 { return }
                } catch {
                    continue
                }
            }
            NSLog("[QuickAccess] All resize attempts failed for %@", label)
        }
    }
}
