import Carbon.HIToolbox
import Cocoa
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var config: Config = Config(sites: [])
    let configPath = Defaults.configPath
    var settingsWindow: NSWindow?
    var qaWindow: NSWindow?
    var settingsVM: SettingsViewModel?
    let resizeQueue = DispatchQueue(label: "com.mingyupark.Chap.resize")
    private var menuIsOpen = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateConfigIfNeeded()
        copyDefaultConfigIfNeeded()
        loadConfig()
        applyLoginItem(enabled: config.launchAtLogin)
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        if let button = statusItem.button {
            if let icon = NSImage(named: "StatusBarIcon") {
                icon.isTemplate = true
                icon.size = NSSize(width: 22, height: 22)
                button.image = icon
            } else {
                button.image = NSImage(
                    systemSymbolName: "bolt.fill", accessibilityDescription: "Chap")
            }
        }
        buildMenu()
        registerGlobalShortcuts()

        let guideDisabled = UserDefaults.standard.bool(forKey: "guideDisabled")
        if !guideDisabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showWelcomeWindow()
            }
        }
    }

    // MARK: - Global Shortcuts

    private var eventTap: CFMachPort?
    private var activationObserver: NSObjectProtocol?
    private var tapRetryCount = 0

    private func registerGlobalShortcuts() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon)
                        .takeUnretainedValue()

                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        if let tap = appDelegate.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                        // re-enable 후에도 권한이 없으면 사용자에게 알림
                        if !AXIsProcessTrusted() {
                            NSLog("[Chap] Accessibility permission revoked")
                            DispatchQueue.main.async {
                                appDelegate.updateStatusIcon(accessible: false)
                                LauncherUtils.showAlert(
                                    message: "Accessibility Permission Lost",
                                    info: "Chap의 접근성 권한이 제거되었습니다.\nSystem Settings → Privacy & Security → Accessibility에서 다시 허용해주세요.")
                            }
                        } else {
                            NSLog("[Chap] CGEvent tap re-enabled after system disable")
                        }
                        return Unmanaged.passRetained(event)
                    }

                    let flags = event.flags.intersection([
                        .maskAlternate, .maskShift, .maskCommand, .maskControl,
                    ])
                    guard flags == .maskAlternate else { return Unmanaged.passRetained(event) }

                    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

                    // ⌥. — open menu (block while menu is open)
                    if keyCode == 47 {
                        guard !appDelegate.menuIsOpen else { return nil }
                        appDelegate.menuIsOpen = true
                        DispatchQueue.main.async {
                            guard let button = appDelegate.statusItem.button else {
                                appDelegate.menuIsOpen = false
                                return
                            }
                            appDelegate.statusItem.menu?.popUp(
                                positioning: nil, at: .zero, in: button)
                            appDelegate.menuIsOpen = false
                        }
                        return nil
                    }

                    // ⌥ + 커스텀 키 — launch site by shortcut
                    if let char = keyCodeToChar(keyCode) {
                        let upper = char.uppercased()
                        if let site = appDelegate.config.sites.first(where: {
                            $0.shortcut?.uppercased() == upper
                        }) {
                            DispatchQueue.main.async {
                                appDelegate.launchSite(site)
                            }
                            return nil
                        }
                    }

                    // ⌥, — open settings
                    if keyCode == 43 {
                        DispatchQueue.main.async {
                            appDelegate.openSettings()
                        }
                        return nil
                    }

                    return Unmanaged.passRetained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            NSLog("[Chap] Failed to create CGEvent tap — check Accessibility permission")
            updateStatusIcon(accessible: false)
            tapRetryCount += 1
            if tapRetryCount <= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    if self?.eventTap == nil {
                        self?.registerGlobalShortcuts()
                    }
                }
            } else {
                observeActivationForAccessibility()
            }
            return
        }

        eventTap = tap
        tapRetryCount = 0
        removeActivationObserver()
        updateStatusIcon(accessible: true)
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[Chap] CGEvent tap registered successfully")
    }

    private func observeActivationForAccessibility() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self = self, self.eventTap == nil else { return }
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                app.bundleIdentifier == Bundle.main.bundleIdentifier
            else { return }
            if AXIsProcessTrusted() {
                NSLog("[Chap] Accessibility granted — attempting shortcut registration")
                self.tapRetryCount = 0
                self.registerGlobalShortcuts()
            }
        }
    }

    private func removeActivationObserver() {
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activationObserver = nil
        }
    }

    private func updateStatusIcon(accessible: Bool) {
        DispatchQueue.main.async {
            guard let button = self.statusItem.button else { return }
            if accessible, let icon = NSImage(named: "StatusBarIcon") {
                icon.isTemplate = true
                icon.size = NSSize(width: 22, height: 22)
                button.image = icon
            } else {
                let iconName = accessible ? "bolt.fill" : "bolt.trianglebadge.exclamationmark"
                button.image = NSImage(
                    systemSymbolName: iconName, accessibilityDescription: "Chap")
            }
        }
    }

    func showWelcomeWindow() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: Text("")))
        // [weak window] 캡처로 window → view → closure → window 순환 참조 방지
        let welcomeView = WelcomeView(onOpenSettings: { [weak self] in
            self?.openSettings()
        }, onClose: { [weak window] in
            window?.close()
        })
        window.contentViewController = NSHostingController(rootView: welcomeView)
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 420, height: 480))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Config handling

    // MARK: - Config migration

    /// 기존 ~/.quickaccess.json → ~/.chap.json 마이그레이션
    func migrateConfigIfNeeded() {
        let oldPath = NSString(string: "~/.quickaccess.json").expandingTildeInPath
        if FileManager.default.fileExists(atPath: oldPath)
            && !FileManager.default.fileExists(atPath: configPath)
        {
            try? FileManager.default.moveItem(atPath: oldPath, toPath: configPath)
            NSLog("[Chap] Migrated config from ~/.quickaccess.json to ~/.chap.json")
        }
    }

    func copyDefaultConfigIfNeeded() {
        if !FileManager.default.fileExists(atPath: configPath) {
            let defaultJSON = """
                {
                  "sites": [
                    {"name": "Google", "url": "https://www.google.com/", "width": 600, "height": 400, "x": 100, "y": 100, "launchType": "url"},
                    {"name": "GitHub", "url": "https://github.com/", "width": 800, "height": 600, "x": 100, "y": 100, "launchType": "url"},
                    {"name": "Downloads", "url": "", "width": 1000, "height": 400, "x": 100, "y": 100, "launchType": "finder", "folderPath": "~/Downloads"}
                  ]
                }
                """
            do {
                try defaultJSON.write(toFile: configPath, atomically: true, encoding: .utf8)
            } catch {
                NSLog(
                    "[Chap] Failed to write default config: %@", error.localizedDescription)
            }
        }
    }

    func loadConfig() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            NSLog("[Chap] Failed to read config file at %@", configPath)
            config = .default
            return
        }
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            NSLog("[Chap] Config decode error: %@", error.localizedDescription)
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Config file is corrupted"
                alert.informativeText = "~/.chap.json을 읽을 수 없어 기본 설정을 사용합니다.\n백업 파일: ~/.chap.json.bak\n\nError: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
            }
            config = .default
        }
    }

    func buildMenu() {
        let menu = NSMenu()
        let sortedSites = config.sites.enumerated().sorted {
            LaunchType.allCases.firstIndex(of: $0.element.launchType)!
                < LaunchType.allCases.firstIndex(of: $1.element.launchType)!
        }
        var lastType: LaunchType? = nil
        for (i, site) in sortedSites {
            // 타입이 바뀌면 구분선 추가
            if let last = lastType, last != site.launchType {
                menu.addItem(.separator())
            }
            lastType = site.launchType
            let keyEquiv = site.shortcut?.lowercased() ?? ""
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
            item.tag = i
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(
            title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = .option
        settings.target = self
        menu.addItem(settings)
        let qa = NSMenuItem(
            title: "Q&A", action: #selector(openQA), keyEquivalent: "")
        qa.target = self
        menu.addItem(qa)
        let about = NSMenuItem(
            title: "About Chap", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        let restart = NSMenuItem(title: "Restart", action: #selector(restartApp), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc func openQA() {
        if let w = qaWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hostingController = NSHostingController(rootView: QAView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Chap Q&A"
        window.setContentSize(NSSize(width: 1120, height: 900))
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 400)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        qaWindow = window
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Chap"
        alert.informativeText = "Version \(Defaults.appVersion)\n\nMade by Team Chap"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Site opening

    @objc func openSite(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < config.sites.count else { return }
        launchSite(config.sites[index])
    }

    func launchSite(_ site: Site) {
        let useGuide = config.showGuideWindow && site.launchType == .url
        if useGuide, let screen = targetScreen(for: site) {
            let bounds = centeredBounds(for: site, on: screen)
            GuideWindow.show(bounds: bounds)
        }

        switch site.launchType {
        case .url:
            ChromeLauncher.launch(site, resizeQueue: resizeQueue) {
                if useGuide { GuideWindow.dismiss() }
            }
        case .app:
            AppLauncher.launch(site, resizeQueue: resizeQueue)
        case .finder:
            guard let path = site.folderPath, !path.isEmpty else {
                LauncherUtils.showAlert(message: "No folder path configured for \"\(site.name)\".")
                return
            }
            let expandedPath = NSString(string: path).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                LauncherUtils.showAlert(message: "Folder not found: \(path)")
                return
            }
            guard let screen = targetScreen(for: site) else {
                // 사용 가능한 화면이 없으면 리사이즈 없이 폴더만 연다
                NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
                return
            }
            let bounds = centeredBounds(for: site, on: screen)
            FinderLauncher.openAndResize(
                path: expandedPath, bounds: (bounds.left, bounds.top, bounds.right, bounds.bottom))
        case .shell: ShellLauncher.launch(site)
        }
    }

    // MARK: - Settings

    @objc func openSettings() {
        if let w = settingsWindow, w.isVisible {
            // 이미 열려 있어도 커서가 있는 화면 중앙으로 이동
            moveToCursorScreenCenter(w)
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = SettingsViewModel(
            sites: config.sites,
            showGuideWindow: config.showGuideWindow, launchAtLogin: config.launchAtLogin)
        vm.onSave = { [weak self] payload in
            guard let self = self else { return false }
            let newConfig = Config(
                showGuideWindow: payload.showGuideWindow,
                launchAtLogin: payload.launchAtLogin, sites: payload.sites)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            do {
                let data = try encoder.encode(newConfig)
                let bakPath = self.configPath + ".bak"
                try? FileManager.default.removeItem(atPath: bakPath)
                try? FileManager.default.copyItem(atPath: self.configPath, toPath: bakPath)
                try data.write(to: URL(fileURLWithPath: self.configPath), options: .atomic)
            } catch {
                NSLog("[Chap] Failed to save config: %@", error.localizedDescription)
                LauncherUtils.showAlert(
                    message: "Failed to save settings",
                    info: "설정을 \(self.configPath)에 저장하지 못했습니다.\n\nError: \(error.localizedDescription)")
                return false
            }
            self.config = newConfig
            self.applyLoginItem(enabled: payload.launchAtLogin)
            DispatchQueue.main.async { self.buildMenu() }
            return true
        }
        vm.onReload = { [weak self] in
            self?.reloadConfig()
        }

        let settingsView = SettingsView(vm: vm)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Chap Settings"
        window.setContentSize(NSSize(width: 700, height: 580))
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)
        window.delegate = self
        // 커서가 있는 화면 중앙에 표시
        moveToCursorScreenCenter(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
        settingsVM = vm
    }

    /// 윈도우를 커서가 있는 화면의 중앙으로 이동
    private func moveToCursorScreenCenter(_ window: NSWindow) {
        guard let screen = cursorScreen else { return }
        let frameSize = window.frame.size
        window.setFrameOrigin(
            NSPoint(
                x: screen.visibleFrame.midX - frameSize.width / 2,
                y: screen.visibleFrame.midY - frameSize.height / 2))
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
            if alert.runModal() != .alertFirstButtonReturn {
                return false
            }
        }
        settingsVM = nil
        settingsWindow = nil
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

    @objc func restartApp() {
        let appPath = Bundle.main.bundlePath
        // 1초 후 재실행하는 백그라운드 프로세스를 띄운 후 종료
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; open \"\(appPath)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    @objc func uninstallApp() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Chap?"
        alert.informativeText =
            "This will remove the app and settings.\n\nNote: Please manually remove Chap from\nSystem Settings → Privacy → Accessibility."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // Login Item 해제
        applyLoginItem(enabled: false)

        // 권한 리셋
        let resetTask = Process()
        resetTask.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        resetTask.arguments = ["reset", "AppleEvents", "com.mingyupark.Chap"]
        try? resetTask.run()
        resetTask.waitUntilExit()
        // 설정 파일 삭제
        try? FileManager.default.removeItem(atPath: configPath)
        try? FileManager.default.removeItem(atPath: configPath + ".bak")

        // 앱을 Trash로 이동
        NSWorkspace.shared.recycle([URL(fileURLWithPath: Bundle.main.bundlePath)]) { _, _ in
            NSApp.terminate(nil)
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Login Item

    private func applyLoginItem(enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSLog(
                "[Chap] Login item %@: %@", enabled ? "register" : "unregister",
                error.localizedDescription)
        }
    }
}

// MARK: - Key Code → Character mapping

/// 현재 키보드 레이아웃 기준으로 keyCode를 문자로 변환 (US 하드코딩 대신 UCKeyTranslate 사용)
/// AZERTY/Dvorak 등 비-US 배열에서도 표기된 키와 실제 키가 일치함
private func keyCodeToChar(_ keyCode: UInt16) -> String? {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
        let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return nil }
    let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
    return layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> String? in
        guard
            let keyboardLayout = buffer.baseAddress?.assumingMemoryBound(
                to: UCKeyboardLayout.self)
        else { return nil }
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        // modifierKeyState=0: ⌥ 조합이 아닌 기본 문자를 얻기 위함 (⌥T → "t")
        let error = UCKeyTranslate(
            keyboardLayout, keyCode, UInt16(kUCKeyActionDisplay), 0,
            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState, chars.count, &length, &chars)
        guard error == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
