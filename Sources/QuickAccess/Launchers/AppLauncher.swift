import Cocoa

/// Launches a macOS app and resizes its window via System Events AppleScript.
enum AppLauncher {
    static func launch(_ site: Site, resizeQueue: DispatchQueue) {
        guard let path = site.appPath, !path.isEmpty else {
            showAlert(message: "No app path configured for \"\(site.name)\".")
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            showAlert(message: "App not found at: \(path)")
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))

        let appName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let screen = targetScreen(for: site)
        let bounds = centeredBounds(for: site, on: screen)
        let bw = site.width
        let bh = site.height

        let appleScript = """
        tell application "System Events"
            tell process "\(appName)"
                repeat 30 times
                    if (count of windows) > 0 then
                        set size of front window to {\(bw), \(bh)}
                        set position of front window to {\(bounds.left), \(bounds.top)}
                        delay 0.1
                        set position of front window to {\(bounds.left), \(bounds.top)}
                        return
                    end if
                    delay 0.3
                end repeat
            end tell
        end tell
        """

        guard checkAccessibility() else { return }

        let delays: [Double] = [0.5, 1.5, 3.0]
        resizeQueue.async {
            for d in delays {
                Thread.sleep(forTimeInterval: d)
                let scriptTask = Process()
                scriptTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                scriptTask.arguments = ["-e", appleScript]
                try? scriptTask.run()
                scriptTask.waitUntilExit()
                if scriptTask.terminationStatus == 0 { return }
            }
        }
    }

    private static var accessibilityPromptShown = false

    private static func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted { return true }
        if !accessibilityPromptShown {
            accessibilityPromptShown = true
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return false
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
