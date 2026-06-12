import Cocoa

/// 쉘 스크립트를 실행하는 런처
/// 윈도우 리사이즈 없음 — 스크립트가 반드시 윈도우를 생성하지 않으므로
enum ShellLauncher {
    /// 사용자가 설정한 쉘 스크립트를 실행
    /// - Parameter site: 실행할 사이트 정보 (script 필드 사용)
    static func launch(_ site: Site) {
        // 스크립트 유효성 확인
        guard let script = site.script, !script.isEmpty else {
            LauncherUtils.showAlert(message: "No script configured for \"\(site.name)\".")
            return
        }

        // 사용자의 기본 쉘 사용 (SHELL 환경변수, 없으면 zsh)
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-c", script]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe

        // 백그라운드에서 실행 (UI 블로킹 방지)
        DispatchQueue.global().async {
            do {
                try process.run()
                process.waitUntilExit()
                // 0이 아닌 종료 코드 = 실패 → 에러 내용을 alert로 표시
                if process.terminationStatus != 0 {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    LauncherUtils.showAlert(message: "Script failed (exit \(process.terminationStatus))", info: errorStr)
                }
            } catch {
                LauncherUtils.showAlert(message: "Failed to execute script.", info: error.localizedDescription)
            }
        }
    }
}
