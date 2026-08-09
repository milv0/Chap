import Cocoa
import os

/// 쉘 스크립트를 실행하는 런처.
/// 스크립트는 60초 timeout과 stdout/stderr 각각 64 KiB 제한 아래 실행된다.
enum ShellLauncher {
    private static let timeout: TimeInterval = 60
    private static let outputLimit = 64 * 1024

    static func launch(_ site: Site) {
        guard let script = site.script, !script.isEmpty else {
            Log.launcher.error("No script configured for \(site.name, privacy: .private)")
            LauncherUtils.showAlert(message: "No script configured for \"\(site.name)\".")
            return
        }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        DispatchQueue.global(qos: .utility).async {
            do {
                let result = try ProcessRunner.run(
                    executable: shell,
                    arguments: ["-c", script],
                    timeout: timeout,
                    outputLimit: outputLimit)

                if result.timedOut {
                    Log.launcher.error(
                        "Shell script timed out for \(site.name, privacy: .private) after \(timeout, privacy: .public)s"
                    )
                    LauncherUtils.showAlert(
                        message: "Script timed out",
                        info: "스크립트가 \(Int(timeout))초 안에 끝나지 않아 중단했습니다.")
                    return
                }

                guard result.exitStatus == 0 else {
                    let output = failureOutput(from: result)
                    Log.launcher.error(
                        "Shell script failed for \(site.name, privacy: .private) (exit \(result.exitStatus)): \(output, privacy: .private)"
                    )
                    LauncherUtils.showAlert(
                        message: "Script failed (exit \(result.exitStatus))", info: output)
                    return
                }

                Log.launcher.notice("Shell script succeeded for \(site.name, privacy: .private)")
            } catch {
                Log.launcher.error(
                    "Failed to execute script for \(site.name, privacy: .private): \(error.localizedDescription, privacy: .public)"
                )
                LauncherUtils.showAlert(
                    message: "Failed to execute script.", info: error.localizedDescription)
            }
        }
    }

    private static func failureOutput(from result: ProcessRunner.Result) -> String {
        let raw = result.stderr.isEmpty ? result.stdoutString : result.stderrString
        let fallback = raw.isEmpty ? "No error output." : raw
        if result.stderrTruncated || result.stdoutTruncated {
            return fallback + "\n\n… output truncated"
        }
        return fallback
    }
}
