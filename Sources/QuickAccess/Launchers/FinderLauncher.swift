import Cocoa

/// Finder 폴더를 열고 윈도우 크기를 설정하는 런처
/// 단일 AppleScript로 열기 + 리사이즈를 동시에 처리하므로 딜레이가 필요 없음
enum FinderLauncher {
    /// Finder로 폴더를 열고 즉시 윈도우 bounds를 설정
    /// - Parameters:
    ///   - path: 열 폴더의 POSIX 경로 (틸드 확장 완료된 상태)
    ///   - bounds: AppleScript bounds (left, top, right, bottom) — 좌상단 원점 좌표계
    static func openAndResize(path: String, bounds: (Int, Int, Int, Int)) {
        // AppleScript 큰따옴표 문자열 내 이스케이프: \ → \\, " → \"
        let posixPath = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        // AppleScript: Finder 활성화 → 폴더 열기 → 윈도우 크기 설정 (한 번에 실행)
        let script = """
        tell application "Finder"
            set targetFolder to (POSIX file "\(posixPath)") as alias
            open targetFolder
            set bounds of front window to {\(bounds.0), \(bounds.1), \(bounds.2), \(bounds.3)}
            activate
        end tell
        """

        // 백그라운드에서 AppleScript 실행
        DispatchQueue.global().async {
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                // 실패 시 에러 로깅 (사용자에게 alert 안 띄움 — Finder는 거의 실패 안 함)
                if task.terminationStatus != 0 {
                    let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    NSLog("[QuickAccess] Finder resize failed: %@", err)
                }
            } catch {
                NSLog("[QuickAccess] Failed to run Finder script: %@", error.localizedDescription)
            }
        }
    }
}
