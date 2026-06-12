import Cocoa

/// Executes a shell script. No window resize — scripts may not produce windows.
enum ShellLauncher {
    static func launch(_ site: Site) {
        guard let script = site.script, !script.isEmpty else {
            showAlert(message: "No script configured for \"\(site.name)\".")
            return
        }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-c", script]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe

        DispatchQueue.global().async {
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    showAlert(message: "Script failed (exit \(process.terminationStatus))", info: errorStr)
                }
            } catch {
                showAlert(message: "Failed to execute script.", info: error.localizedDescription)
            }
        }
    }

    private static func showAlert(message: String, info: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            if let info = info { alert.informativeText = info }
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
