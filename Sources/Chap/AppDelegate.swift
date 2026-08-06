import Cocoa
import ServiceManagement
import SwiftUI
import os

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private enum AccessibilityState {
        case unknown
        case granted
        case denied
    }

    private enum AccessibilityGrantPolling {
        static let interval: TimeInterval = 2.0
        static let duration: TimeInterval = 30.0
    }

    var statusItem: NSStatusItem!
    var config: Config = Config(sites: [])
    let configPath = Defaults.configPath
    private let configStore = ConfigStore()
    var settingsWindow: NSWindow?
    var qaWindow: NSWindow?
    var welcomeWindow: NSWindow?
    var settingsVM: SettingsViewModel?
    private let globalHotKeyManager = GlobalHotKeyManager()
    private var isStatusMenuOpen = false
    private var accessibilityState: AccessibilityState = .unknown
    private var accessibilityGrantPollTimer: Timer?
    private var accessibilityGrantPollEndDate: Date?
    private var didShowAccessibilityAlert = false
    private var didRequestAccessibilitySystemPrompt = false
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateConfigIfNeeded()
        copyDefaultConfigIfNeeded()
        loadConfig()
        stripLegacyConfigFields()
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
        initializeAccessibilityHandling()

        let guideDisabled = UserDefaults.standard.bool(forKey: "guideDisabled")
        if !guideDisabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showWelcomeWindow()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalHotKeyManager.stop()
    }

    private func initializeAccessibilityHandling() {
        let shouldPromptUser = !isRunningTests
        refreshAccessibilityState(
            reason: "launch", showAlert: false,
            requestSystemPrompt: shouldPromptUser)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActiveNotification),
            name: NSApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(axResizeDidFailNotification),
            name: .chapAXResizeFailed,
            object: nil)
    }

    @objc private func applicationDidBecomeActiveNotification(_ notification: Notification) {
        refreshAccessibilityState(reason: "app active", showAlert: false)
    }

    @objc private func axResizeDidFailNotification(_ notification: Notification) {
        refreshAccessibilityState(reason: "resize failure", showAlert: true)
    }

    private func startTemporaryAccessibilityGrantPolling(reason: String) {
        guard !isRunningTests else { return }
        accessibilityGrantPollEndDate = Date().addingTimeInterval(
            AccessibilityGrantPolling.duration)
        guard accessibilityGrantPollTimer == nil else { return }

        let timer = Timer(timeInterval: AccessibilityGrantPolling.interval, repeats: true) {
            [weak self] _ in
            self?.pollAccessibilityGrant(reason: reason)
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityGrantPollTimer = timer
    }

    private func pollAccessibilityGrant(reason: String) {
        if let endDate = accessibilityGrantPollEndDate, Date() > endDate {
            stopTemporaryAccessibilityGrantPolling()
            return
        }
        refreshAccessibilityState(reason: reason, showAlert: false)
    }

    private func stopTemporaryAccessibilityGrantPolling() {
        accessibilityGrantPollTimer?.invalidate()
        accessibilityGrantPollTimer = nil
        accessibilityGrantPollEndDate = nil
    }

    private func refreshAccessibilityState(
        reason: String, showAlert: Bool, requestSystemPrompt: Bool = false
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.refreshAccessibilityState(
                    reason: reason, showAlert: showAlert, requestSystemPrompt: requestSystemPrompt)
            }
            return
        }

        let isTrusted = AccessibilityPermission.isTrusted
        let previousState = accessibilityState
        accessibilityState = isTrusted ? .granted : .denied
        updateStatusIcon(accessible: isTrusted)

        if isTrusted {
            stopTemporaryAccessibilityGrantPolling()
            didShowAccessibilityAlert = false
            return
        }

        if requestSystemPrompt {
            requestAccessibilitySystemPromptIfNeeded()
            startTemporaryAccessibilityGrantPolling(reason: "permission prompt")
        }

        let wasRevoked = previousState == .granted
        if wasRevoked {
            Log.app.error("Accessibility permission revoked from \(reason, privacy: .public)")
        }

        if wasRevoked || showAlert, !didShowAccessibilityAlert {
            didShowAccessibilityAlert = true
            showAccessibilityAlert()
        }
    }

    private func requestAccessibilitySystemPromptIfNeeded() {
        guard !didRequestAccessibilitySystemPrompt else { return }
        didRequestAccessibilitySystemPrompt = true
        AccessibilityPermission.requestSystemPrompt()
    }

    // NSMenuDelegate — 메뉴바 메뉴가 열릴 때 권한 재확인
    func menuWillOpen(_ menu: NSMenu) {
        refreshAccessibilityState(reason: "menu", showAlert: false)
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

    /// 시스템 설정의 접근성 창을 직접 연다
    func openAccessibilitySettings() {
        if let url = URL(
            string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
            startTemporaryAccessibilityGrantPolling(reason: "accessibility settings")
        }
    }

    /// 접근성 권한이 없을 때, 시스템 설정으로 바로 이동하는 버튼이 포함된 알림
    func showAccessibilityAlert() {
        DispatchQueue.main.async {
            guard !AccessibilityPermission.isTrusted else {
                self.didShowAccessibilityAlert = false
                self.updateStatusIcon(accessible: true)
                return
            }
            let alert = NSAlert()
            alert.messageText = "Allow Accessibility"
            alert.informativeText = "System Settings에서 Chap을 허용해주세요."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            }
        }
    }

    func showWelcomeWindow() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: Text("")))
        // [weak window] 캡처로 window → view → closure → window 순환 참조 방지
        let welcomeView = WelcomeView(
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onClose: { [weak window] in
                window?.close()
            })
        window.contentViewController = NSHostingController(rootView: welcomeView)
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 420, height: 480))
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow = window
    }

    // MARK: - Config handling

    // MARK: - Config migration

    /// 기존 ~/.quickaccess.json → ~/.chap.json 마이그레이션
    func migrateConfigIfNeeded() {
        do {
            if try configStore.migrateLegacyConfigPathIfNeeded() {
                Log.config.info("Migrated config from ~/.quickaccess.json to ~/.chap.json")
            }
        } catch {
            Log.config.error(
                "Failed to migrate legacy config: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 설정 파일에 남아 있는 레거시 필드(x, y, hotkey, showGhostWindow 등)를 제거.
    /// loadConfig() 후 호출하면 decode→encode 과정에서 레거시 키가 자동 탈락하므로,
    /// 파일 원본에 해당 키가 있으면 한 번 덮어써서 정리한다.
    func stripLegacyConfigFields() {
        do {
            if try configStore.stripLegacyFieldsIfNeeded(using: config) {
                Log.config.info("Stripped legacy fields from config file")
            }
        } catch {
            Log.config.error(
                "Failed to strip legacy fields: \(error.localizedDescription, privacy: .public)")
        }
    }

    func copyDefaultConfigIfNeeded() {
        do {
            _ = try configStore.createDefaultConfigIfNeeded()
        } catch {
            Log.config.error(
                "Failed to write default config: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func loadConfig() {
        let connectedDisplays = NSScreen.screens.map {
            DisplayMatchCandidate(identifier: displayUUID(for: $0), name: $0.localizedName)
        }
        do {
            let result = try configStore.load(connectedDisplays: connectedDisplays)
            config = result.config
            if result.didAutoSaveDisplayMigration {
                Log.config.info("Auto-saved display UUID migration")
            }
            for warning in result.displayWarnings {
                Log.config.warning(
                    "Display migration: \(warning.message, privacy: .public)")
            }
        } catch ConfigStoreError.readFailed {
            Log.config.error("Failed to read config file at \(self.configPath, privacy: .public)")
            config = .default
        } catch {
            Log.config.error("Config decode error: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Config file is corrupted"
                alert.informativeText =
                    "~/.chap.json을 읽을 수 없어 기본 설정을 사용합니다.\n백업 파일: ~/.chap.json.bak\n\nError: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
            }
            config = .default
        }
    }

    func buildMenu() {
        let menu = NSMenu()
        let launchTypeOrder = Dictionary(
            uniqueKeysWithValues: LaunchType.allCases.enumerated().map { ($1, $0) })
        let sortedSites = config.sites.enumerated().sorted {
            launchTypeOrder[$0.element.launchType, default: Int.max]
                < launchTypeOrder[$1.element.launchType, default: Int.max]
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
        qa.image = NSImage(
            systemSymbolName: "questionmark.circle", accessibilityDescription: "Q&A")
        qa.target = self
        menu.addItem(qa)
        let bug = NSMenuItem(
            title: "Report Bug", action: #selector(reportBug), keyEquivalent: "")
        bug.image = NSImage(systemSymbolName: "ladybug", accessibilityDescription: "Report Bug")
        bug.target = self
        menu.addItem(bug)
        let about = NSMenuItem(
            title: "About Chap", action: #selector(showAbout), keyEquivalent: "")
        about.image = NSImage(
            systemSymbolName: "info.circle", accessibilityDescription: "About Chap")
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
        menu.delegate = self
        statusItem.menu = menu
        configureGlobalHotKeys()
    }

    private func configureGlobalHotKeys() {
        guard !isRunningTests else { return }
        globalHotKeyManager.configure(sites: config.sites) { [weak self] action in
            self?.handleGlobalHotKeyAction(action)
        }
    }

    private func handleGlobalHotKeyAction(_ action: GlobalHotKeyAction) {
        switch action {
        case .openMenu:
            openStatusMenu()
        case .openSettings:
            openSettings()
        case .launchSite(let index):
            guard config.sites.indices.contains(index) else { return }
            launchSite(config.sites[index])
        }
    }

    private func openStatusMenu() {
        guard !isStatusMenuOpen, let button = statusItem.button else { return }
        isStatusMenuOpen = true
        statusItem.menu?.popUp(positioning: nil, at: .zero, in: button)
        isStatusMenuOpen = false
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
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
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

    @objc func reportBug() {
        if let url = URL(string: "https://github.com/milv0/Chap/issues/new") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Site opening

    @objc func openSite(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < config.sites.count else { return }
        launchSite(config.sites[index])
    }

    func launchSite(_ site: Site) {
        let needsAccessibility = site.launchType == .url || site.launchType == .app
        refreshAccessibilityState(reason: "launch", showAlert: needsAccessibility)

        var guideToken: Int?
        if config.showGuideWindow, site.launchType == .url, let screen = targetScreen(for: site) {
            let bounds = centeredBounds(for: site, on: screen)
            guideToken = GuideWindow.show(bounds: bounds)
        }

        switch site.launchType {
        case .url:
            ChromeLauncher.launch(site) {
                if let token = guideToken { GuideWindow.dismiss(token) }
            }
        case .app:
            AppLauncher.launch(site)
        case .finder:
            guard let path = site.folderPath, !path.isEmpty else {
                Log.launcher.error("No folder path configured for \(site.name, privacy: .private)")
                LauncherUtils.showAlert(message: "No folder path configured for \"\(site.name)\".")
                return
            }
            let expandedPath = NSString(string: path).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                Log.launcher.error("Folder not found: \(expandedPath, privacy: .private)")
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
        refreshAccessibilityState(reason: "settings", showAlert: false)
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
            // Full config validation before saving
            let validationConfig = Config(
                showGuideWindow: payload.showGuideWindow,
                launchAtLogin: payload.launchAtLogin, sites: payload.sites)
            let result = validateConfig(validationConfig)
            if !result.isValid {
                let errorMessages = result.errors.map { issue in
                    "[\(issue.siteIndex + 1)] \(issue.message)"
                }.joined(separator: "\n")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Cannot save settings"
                    alert.informativeText =
                        "Please fix the following errors:\n\n\(errorMessages)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return false
            }
            let newConfig = validationConfig
            do {
                try self.configStore.save(newConfig)
            } catch {
                Log.config.error(
                    "Failed to save config: \(error.localizedDescription, privacy: .public)")
                LauncherUtils.showAlert(
                    message: "Failed to save settings",
                    info:
                        "설정을 \(self.configPath)에 저장하지 못했습니다.\n\nError: \(error.localizedDescription)"
                )
                return false
            }
            self.config = newConfig
            self.applyLoginItem(enabled: payload.launchAtLogin)
            DispatchQueue.main.async { self.buildMenu() }
            return true
        }
        let settingsView = SettingsView(vm: vm)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Chap Settings"
        window.setContentSize(NSSize(width: 770, height: 600))
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
        // Settings window: check for unsaved changes
        if sender == settingsWindow {
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
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == settingsWindow {
            settingsVM = nil
            settingsWindow = nil
        } else if window == qaWindow {
            qaWindow = nil
        } else if window == welcomeWindow {
            welcomeWindow = nil
        }
        // 모든 관리 창이 닫히면 accessory로 복원
        restoreAccessoryIfNeeded()
    }

    /// 모든 관리 창(Settings, QA, Welcome)이 닫혀 있을 때 activation policy를
    /// accessory로 복원하여 Dock 아이콘을 숨긴다.
    private func restoreAccessoryIfNeeded() {
        let hasVisibleWindow =
            (settingsWindow?.isVisible ?? false)
            || (qaWindow?.isVisible ?? false)
            || (welcomeWindow?.isVisible ?? false)
        if !hasVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
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
        resetTask.arguments = [
            "reset", "AppleEvents", Bundle.main.bundleIdentifier ?? "com.mingyupark.Chap",
        ]
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
        // 이미 목표 상태면 호출 생략. 특히 미등록 상태에서 unregister()는
        // 매 실행 throw하므로(정상 실행마다 로그 노이즈), status로 먼저 거른다.
        let isRegistered = service.status == .enabled
        guard enabled != isRegistered else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Log.app.error(
                "Login item \(enabled ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
