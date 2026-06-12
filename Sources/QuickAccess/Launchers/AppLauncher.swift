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

        // Resolve names from Info.plist — .app filename and process name often
        // differ (e.g. "Visual Studio Code.app" → "Code").
        let bundle = Bundle(path: path)
        let bundleId = bundle?.bundleIdentifier
        let processName =
            bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        let screen = targetScreen(for: site)
        let bounds = centeredBounds(for: site, on: screen)
        let bw = site.width
        let bh = site.height

        NSLog(
            "[AppLauncher] launch site=%@ path=%@ bundleId=%@ processName=%@",
            site.name, path, bundleId ?? "nil", processName)
        NSLog(
            "[AppLauncher] target screen=%@ bounds={left:%d, top:%d, w:%d, h:%d}",
            screen.localizedName, bounds.left, bounds.top, bw, bh)

        // Resize requires Accessibility. If unavailable, still launch the app
        // but skip the AppleScript reposition step.
        let canResize = checkAccessibility()
        if !canResize {
            NSLog("[AppLauncher] Accessibility not granted — launching without resize")
        }

        let activateClause: String
        if let id = bundleId {
            activateClause = "tell application id \"\(id)\" to activate"
        } else {
            activateClause = "tell application \"\(processName)\" to activate"
        }

        let appleScript = """
            \(activateClause)
            delay 0.05
            tell application "System Events"
                tell process "\(processName)"
                    repeat 30 times
                        if (count of windows) > 0 then
                            set position of front window to {\(bounds.left), \(bounds.top)}
                            set size of front window to {\(bw), \(bh)}
                            delay 0.05
                            set position of front window to {\(bounds.left), \(bounds.top)}
                            return
                        end if
                        delay 0.3
                    end repeat
                end tell
            end tell
            """

        let appURL = URL(fileURLWithPath: path)
        let openConfig = NSWorkspace.OpenConfiguration()
        openConfig.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { app, error in
            if let error = error {
                NSLog("[AppLauncher] openApplication failed: %@", error.localizedDescription)
                return
            }
            NSLog(
                "[AppLauncher] app opened pid=%d localizedName=%@",
                app?.processIdentifier ?? -1, app?.localizedName ?? "?")

            guard canResize else { return }

            // Delays: shorter if app is already running, longer for cold start
            let appRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == bundleId
            }
            let delays: [Double] = appRunning ? [0.2, 0.5, 0.8, 1.2, 2.0] : [1.0, 2.0, 3.5, 5.0]
            resizeQueue.async {
                for d in delays {
                    Thread.sleep(forTimeInterval: d)
                    let scriptTask = Process()
                    let pipe = Pipe()
                    scriptTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    scriptTask.arguments = ["-e", appleScript]
                    scriptTask.standardError = pipe
                    scriptTask.standardOutput = pipe
                    do {
                        try scriptTask.run()
                        scriptTask.waitUntilExit()
                        let output =
                            String(
                                data: pipe.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8) ?? ""
                        NSLog(
                            "[AppLauncher] attempt delay=%.1fs status=%d output=%@",
                            d, scriptTask.terminationStatus, output)
                        if scriptTask.terminationStatus == 0 { return }
                    } catch {
                        NSLog(
                            "[AppLauncher] failed to run osascript: %@",
                            error.localizedDescription)
                    }
                }
                NSLog("[AppLauncher] All resize attempts failed for %@", site.name)
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
