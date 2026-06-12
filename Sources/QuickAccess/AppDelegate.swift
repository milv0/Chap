import Cocoa
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var config: Config = Config(sites: [])
    let configPath = NSString(string: "~/.quickaccess.json").expandingTildeInPath
    var settingsWindow: NSWindow?
    var settingsVM: SettingsViewModel?
    let resizeQueue = DispatchQueue(label: "com.mingyupark.QuickAccess.resize")

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        copyDefaultConfigIfNeeded()
        loadConfig()
        NSApp.setActivationPolicy(config.runInBackground ? .accessory : .regular)

        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "QuickAccess")
        }
        buildMenu()
        registerGlobalHotkeys()

        DispatchQueue.global().async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "tell application \"Google Chrome\" to get name"]
            try? task.run()
            task.waitUntilExit()
        }

        let guideDisabled = UserDefaults.standard.bool(forKey: "guideDisabled")
        if !guideDisabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showWelcomeWindow()
            }
        }
    }

    // MARK: - Global Hotkeys

    private func registerGlobalHotkeys() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleHotkey(event) == true { return nil }
            return event
        }
    }

    @discardableResult
    private func handleHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .option else { return false }

        // ⌥Q — open menu
        if event.keyCode == 12 {
            DispatchQueue.main.async {
                guard let button = self.statusItem.button else { return }
                self.statusItem.menu?.popUp(positioning: nil, at: .zero, in: button)
            }
            return true
        }

        // ⌥1~9 — launch site directly
        let numberKeyCodes: [UInt16: Int] = [
            18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
            22: 5, 26: 6, 28: 7, 25: 8,
        ]
        if let index = numberKeyCodes[event.keyCode],
           index < config.sites.count {
            DispatchQueue.main.async {
                self.launchSite(self.config.sites[index])
            }
            return true
        }

        // ⌥, — open settings
        if event.keyCode == 43 {
            DispatchQueue.main.async {
                self.openSettings()
            }
            return true
        }

        return false
    }

    func showWelcomeWindow() {
        let welcomeView = WelcomeView {
            self.openSettings()
        }
        let controller = NSHostingController(rootView: welcomeView)
        let window = NSWindow(contentViewController: controller)
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 380))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Config handling

    func copyDefaultConfigIfNeeded() {
        if !FileManager.default.fileExists(atPath: configPath) {
            let defaultJSON = """
            {
              "sites": [
                {"name": "Google", "url": "https://www.google.com/", "width": 600, "height": 400, "x": 100, "y": 100},
                {"name": "GitHub", "url": "https://github.com/", "width": 800, "height": 600, "x": 100, "y": 100}
              ]
            }
            """
            do {
                try defaultJSON.write(toFile: configPath, atomically: true, encoding: .utf8)
            } catch {
                NSLog("[QuickAccess] Failed to write default config: %@", error.localizedDescription)
            }
        }
    }

    func loadConfig() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            NSLog("[QuickAccess] Failed to read config file at %@", configPath)
            return
        }
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Cannot read config file. Using defaults."
                alert.alertStyle = .warning
                alert.runModal()
            }
            config = .default
        }
    }

    func buildMenu() {
        let menu = NSMenu()
        for (i, site) in config.sites.enumerated() {
            let keyEquiv = i < 9 ? "\(i + 1)" : ""
            let item = NSMenuItem(title: site.name, action: #selector(openSite(_:)), keyEquivalent: keyEquiv)
            if !keyEquiv.isEmpty {
                item.keyEquivalentModifierMask = .option
            }
            let iconName: String
            switch site.launchType {
            case .url: iconName = "bolt.fill"
            case .app: iconName = "app.fill"
            case .shell: iconName = "terminal.fill"
            }
            item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            item.representedObject = site
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(title: "About QuickAccess", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "QuickAccess"
        alert.informativeText = "Version \(Defaults.appVersion)\n\nMade by Mingyu"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Site opening

    @objc func openSite(_ sender: NSMenuItem) {
        guard let site = sender.representedObject as? Site else { return }
        launchSite(site)
    }

    func launchSite(_ site: Site) {
        switch site.launchType {
        case .url: launchURL(site)
        case .app: launchApp(site)
        case .shell: launchShell(site)
        }
    }

    private func launchURL(_ site: Site) {
        if !FileManager.default.fileExists(atPath: "/Applications/Google Chrome.app") {
            showAlert(message: "Google Chrome is not installed.")
            return
        }

        let rawDomain = URL(string: site.url)?.host ?? ""
        guard isValidDomain(rawDomain) else {
            NSLog("[QuickAccess] Invalid domain: %@", rawDomain)
            return
        }
        let domain = rawDomain

        let screen = targetScreen(for: site)
        let primaryH = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 1080
        let origin = screen.frame.origin
        let screenOffsetX = Int(origin.x)
        let screenOffsetY = Int(primaryH - origin.y - screen.frame.height)
        let bw = site.width
        let bh = site.height
        let bx = screenOffsetX + (Int(screen.frame.width) - bw) / 2
        let by = screenOffsetY + (Int(screen.frame.height) - bh) / 2
        let bounds = "\(bx), \(by), \(bx + bw), \(by + bh)"

        let retries = Defaults.resizeRetries
        let retryInterval = Defaults.retryInterval
        let appleScript = """
        tell application "Google Chrome"
          repeat \(retries) times
            repeat with w in windows
              set tabUrl to URL of active tab of w
              if tabUrl contains "\(domain)" then
                set bounds of w to {\(bounds)}
                return
              end if
            end repeat
            delay \(retryInterval)
          end repeat
          if (count of windows) > 0 then
            set bounds of front window to {\(bounds)}
          end if
        end tell
        """

        let chromeRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.google.Chrome" }

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

    private func launchApp(_ site: Site) {
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
        let primaryH = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 1080
        let origin = screen.frame.origin
        let screenOffsetX = Int(origin.x)
        let screenOffsetY = Int(primaryH - origin.y - screen.frame.height)
        let bw = site.width
        let bh = site.height
        let bx = screenOffsetX + (Int(screen.frame.width) - bw) / 2
        let by = screenOffsetY + (Int(screen.frame.height) - bh) / 2

        let appleScript = """
        tell application "System Events"
            tell process "\(appName)"
                repeat 30 times
                    if (count of windows) > 0 then
                        set size of front window to {\(bw), \(bh)}
                        set position of front window to {\(bx), \(by)}
                        delay 0.1
                        set position of front window to {\(bx), \(by)}
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

    private var accessibilityPromptShown = false

    private func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted { return true }
        if !accessibilityPromptShown {
            accessibilityPromptShown = true
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return false
    }

    private func launchShell(_ site: Site) {
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
                    DispatchQueue.main.async {
                        self.showAlert(message: "Script failed (exit \(process.terminationStatus))", info: errorStr)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to execute script.", info: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(message: String, info: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            if let info = info { alert.informativeText = info }
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - Settings

    @objc func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = SettingsViewModel(sites: config.sites, runInBackground: config.runInBackground)
        vm.onSave = { [weak self] newSites, bg in
            guard let self = self else { return }
            self.config = Config(runInBackground: bg, sites: newSites)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(self.config) {
                try? data.write(to: URL(fileURLWithPath: self.configPath), options: .atomic)
            }
            DispatchQueue.main.async { self.buildMenu() }
        }
        vm.onReload = { [weak self] in
            self?.reloadConfig()
        }

        let settingsView = SettingsView(vm: vm)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "QuickAccess Settings"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
        settingsVM = vm
    }

    @objc func reloadConfig() {
        loadConfig()
        buildMenu()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let vm = settingsVM, vm.hasChanges {
            let alert = NSAlert()
            alert.messageText = "You have unsaved changes."
            alert.informativeText = "Changes will be lost if you close."
            alert.addButton(withTitle: "Close")
            alert.addButton(withTitle: "Cancel")
            return alert.runModal() == .alertFirstButtonReturn
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let vm = settingsVM, vm.hasChanges,
              let window = settingsWindow, window.isVisible else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = "You have unsaved settings."
        alert.informativeText = "Quit without saving?"
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            return .terminateNow
        }
        return .terminateCancel
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
