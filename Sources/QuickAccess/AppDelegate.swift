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
            button.image = NSImage(
                systemSymbolName: "bolt.fill", accessibilityDescription: "QuickAccess")
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
            index < config.sites.count
        {
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
                NSLog(
                    "[QuickAccess] Failed to write default config: %@", error.localizedDescription)
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
            let item = NSMenuItem(
                title: site.name, action: #selector(openSite(_:)), keyEquivalent: keyEquiv)
            if !keyEquiv.isEmpty {
                item.keyEquivalentModifierMask = .option
            }
            let iconName: String
            switch site.launchType {
            case .url: iconName = "bolt.fill"
            case .app: iconName = "app.fill"
            case .finder: iconName = "folder.fill"
            case .shell: iconName = "terminal.fill"
            }
            item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            item.representedObject = site
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(
            title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(
            title: "About QuickAccess", action: #selector(showAbout), keyEquivalent: "")
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
        case .url: ChromeLauncher.launch(site, resizeQueue: resizeQueue)
        case .app: AppLauncher.launch(site, resizeQueue: resizeQueue)
        case .finder:
            guard let path = site.folderPath, !path.isEmpty else {
                showAlert(message: "No folder path configured for \"\(site.name)\".")
                return
            }
            let expandedPath = NSString(string: path).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                showAlert(message: "Folder not found: \(path)")
                return
            }
            let screen = targetScreen(for: site)
            let bounds = centeredBounds(for: site, on: screen)
            FinderLauncher.openAndResize(path: expandedPath, bounds: (bounds.left, bounds.top, bounds.right, bounds.bottom))
        case .shell: ShellLauncher.launch(site)
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
            let window = settingsWindow, window.isVisible
        else {
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
