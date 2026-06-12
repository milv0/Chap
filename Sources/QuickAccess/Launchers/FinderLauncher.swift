import Cocoa

/// Opens a Finder folder and sets window bounds in a single AppleScript execution.
/// No delay needed — open and resize happen atomically in one script.
enum FinderLauncher {
    static func openAndResize(path: String, bounds: (Int, Int, Int, Int)) {
        let posixPath = path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "Finder"
            activate
            set targetFolder to (POSIX file "\(posixPath)") as alias
            open targetFolder
            set bounds of front window to {\(bounds.0), \(bounds.1), \(bounds.2), \(bounds.3)}
        end tell
        """

        DispatchQueue.global().async {
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
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
