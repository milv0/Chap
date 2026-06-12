import Cocoa

/// Launches a URL in Chrome --app mode and resizes the window.
enum ChromeLauncher {
    static func launch(_ site: Site, resizeQueue: DispatchQueue) {
        guard FileManager.default.fileExists(atPath: "/Applications/Google Chrome.app") else {
            showAlert(message: "Google Chrome is not installed.")
            return
        }

        let rawDomain = URL(string: site.url)?.host ?? ""
        guard isValidDomain(rawDomain) else {
            NSLog("[QuickAccess] Invalid domain: %@", rawDomain)
            return
        }

        let screen = targetScreen(for: site)
        let bounds = centeredBounds(for: site, on: screen)
        let boundsStr = "\(bounds.left), \(bounds.top), \(bounds.right), \(bounds.bottom)"

        let retries = Defaults.resizeRetries
        let retryInterval = Defaults.retryInterval
        let appleScript = """
        tell application "Google Chrome"
          repeat \(retries) times
            repeat with w in windows
              set tabUrl to URL of active tab of w
              if tabUrl contains "\(rawDomain)" then
                set bounds of w to {\(boundsStr)}
                return
              end if
            end repeat
            delay \(retryInterval)
          end repeat
          if (count of windows) > 0 then
            set bounds of front window to {\(boundsStr)}
          end if
        end tell
        """

        let chromeRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.google.Chrome"
        }

        let openTask = Process()
        openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openTask.arguments = ["-na", "Google Chrome", "--args", "--app=\(site.url)"]
        do {
            try openTask.run()
        } catch {
            showAlert(message: "Failed to launch Chrome.", info: error.localizedDescription)
            return
        }

        let delays: [Double] = chromeRunning ? [0.5, 0.8, 1.2, 2.0] : [1.0, 2.0, 3.5, 5.0]
        resizeQueue.async {
            for d in delays {
                Thread.sleep(forTimeInterval: d)
                let scriptTask = Process()
                let pipe = Pipe()
                scriptTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                scriptTask.arguments = ["-e", appleScript]
                scriptTask.standardError = pipe
                do {
                    try scriptTask.run()
                    scriptTask.waitUntilExit()
                    if scriptTask.terminationStatus == 0 { return }
                } catch {
                    continue
                }
            }
            NSLog("[QuickAccess] All resize attempts failed")
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
