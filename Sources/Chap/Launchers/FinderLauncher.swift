import Cocoa
import os

/// Finder 폴더를 열고 윈도우 크기를 설정하는 런처.
enum FinderLauncher {
    private static let timeout: TimeInterval = 10
    private static let outputLimit = 32 * 1024

    /// Finder로 폴더를 열고 즉시 윈도우 bounds를 설정한다.
    static func openAndResize(path: String, bounds: (Int, Int, Int, Int)) {
        let script = finderScript(path: path, bounds: bounds)

        DispatchQueue.global(qos: .utility).async {
            do {
                let result = try ProcessRunner.run(
                    executable: "/usr/bin/osascript",
                    arguments: ["-e", script],
                    timeout: timeout,
                    outputLimit: outputLimit)

                if result.timedOut {
                    Log.launcher.error("Finder resize timed out")
                    LauncherUtils.showAlert(
                        message: "Finder did not respond",
                        info:
                            "Finder 창 열기와 크기 조정이 \(Int(timeout))초 안에 완료되지 않았습니다."
                    )
                    return
                }

                guard result.exitStatus == 0 else {
                    let detail =
                        result.stderrString.isEmpty
                        ? "Finder automation failed."
                        : result.stderrString
                    Log.launcher.error("Finder resize failed: \(detail, privacy: .private)")
                    LauncherUtils.showAlert(
                        message: "Could not open or resize Finder",
                        info: detail
                            + "\n\nSystem Settings → Privacy & Security → Automation에서 Chap의 Finder 제어 권한을 확인해주세요."
                    )
                    return
                }
            } catch {
                Log.launcher.error(
                    "Failed to run Finder script: \(error.localizedDescription, privacy: .public)")
                LauncherUtils.showAlert(
                    message: "Failed to run Finder automation", info: error.localizedDescription)
            }
        }
    }

    /// AppleScript 문자열 리터럴에 들어갈 경로를 이스케이프해 스크립트를 만든다.
    static func finderScript(path: String, bounds: (Int, Int, Int, Int)) -> String {
        let posixPath =
            path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
            tell application "Finder"
                set targetFolder to (POSIX file "\(posixPath)") as alias
                open targetFolder
                set bounds of front window to {\(bounds.0), \(bounds.1), \(bounds.2), \(bounds.3)}
                activate
            end tell
            """
    }
}
