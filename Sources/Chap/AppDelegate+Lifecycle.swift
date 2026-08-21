import Cocoa
import ServiceManagement
import SwiftUI
import os

// MARK: - App lifecycle, windows, termination, login item

extension AppDelegate {
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
            button.alignment = .center
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.image = statusIconImage(accessible: true)
        }
        buildMenu()
        accessibilityController.onAccessibleChanged = { [weak self] accessible in
            self?.updateStatusIcon(accessible: accessible)
        }
        accessibilityController.start()

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

    // MARK: - Welcome window

    func showWelcomeWindow() {
        let window = makeManagedWindow(
            title: "", contentSize: NSSize(width: 420, height: 480),
            styleMask: [.titled, .closable])
        window.titlebarAppearsTransparent = true
        // [weak window] 캡처로 window → view → closure → window 순환 참조 방지
        let welcomeView = WelcomeView(
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onOpenAccessibilitySettings: { [weak self] in
                self?.accessibilityController.openAccessibilitySettings()
            },
            onClose: { [weak window] in
                window?.close()
            })
        window.contentViewController = NSHostingController(rootView: welcomeView)
        window.center()
        presentManagedWindow(window)
        welcomeWindow = window
        // TestFlight sandbox build에서는 launch 직전 accessory 상태에서 요청한 AX prompt가
        // 사용자에게 보이지 않을 수 있다. Welcome 창이 key가 된 뒤에 요청한다.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, window?.isVisible == true else { return }
            self.accessibilityController.requestSystemPromptAfterOnboarding()
        }
    }

    // MARK: - Settings

    @objc func openSettings() {
        accessibilityController.refresh(reason: "settings", showAlert: false)
        if let w = settingsWindow, w.isVisible {
            // 이미 열려 있어도 커서가 있는 화면 중앙으로 이동
            moveToCursorScreenCenter(w)
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = SettingsViewModel(
            sites: config.sites,
            showGuideWindow: config.showGuideWindow,
            launchAtLogin: config.launchAtLogin,
            optionShortcutsEnabled: config.optionShortcutsEnabled,
            statusBarIcon: config.statusBarIcon)
        vm.onSave = { [weak self] payload in
            guard let self = self else { return false }
            // Full config validation before saving
            let validationConfig = Config(
                showGuideWindow: payload.showGuideWindow,
                launchAtLogin: payload.launchAtLogin,
                optionShortcutsEnabled: payload.optionShortcutsEnabled,
                statusBarIcon: payload.statusBarIcon,
                sites: payload.sites)
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
            let previousMenu = MenuConfigurationSnapshot(sites: self.config.sites)
            let previousLoginSetting = self.config.launchAtLogin
            let previousOptionShortcutsEnabled = self.config.optionShortcutsEnabled
            let previousStatusBarIcon = self.config.statusBarIcon
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
            if previousLoginSetting != newConfig.launchAtLogin {
                self.applyLoginItem(enabled: payload.launchAtLogin)
            }
            if previousStatusBarIcon != newConfig.statusBarIcon {
                self.statusItem.button?.image = self.statusIconImage(
                    accessible: self.accessibilityController.isAccessible,
                    choice: newConfig.statusBarIcon)
            }
            let newMenu = MenuConfigurationSnapshot(sites: newConfig.sites)
            if previousMenu != newMenu
                || previousOptionShortcutsEnabled != newConfig.optionShortcutsEnabled
            {
                DispatchQueue.main.async { self.buildMenu() }
            }
            return true
        }
        let settingsView = SettingsView(vm: vm)
        let window = makeManagedWindow(
            title: "Chap Settings", contentSize: NSSize(width: 770, height: 680),
            styleMask: [.titled, .closable, .resizable],
            minSize: NSSize(width: 770, height: 680))
        window.contentViewController = NSHostingController(rootView: settingsView)
        // 커서가 있는 화면 중앙에 표시
        moveToCursorScreenCenter(window)
        presentManagedWindow(window)
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

    // MARK: - Window close

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Flush debounced edits before deciding whether anything remains unsaved.
        if sender == settingsWindow {
            settingsVM?.flushPendingSave()
        }
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

    // MARK: - Termination

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        settingsVM?.flushPendingSave()
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = AppLifecycleSupport.restartTaskArguments(
            appPath: Bundle.main.bundlePath)
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            Log.app.error(
                "Failed to schedule app restart: \(error.localizedDescription, privacy: .public)")
            LauncherUtils.showAlert(
                message: "Failed to restart Chap", info: error.localizedDescription)
        }
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

        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        NSWorkspace.shared.recycle([appURL]) { [weak self] _, recycleError in
            DispatchQueue.main.async {
                guard let self else { return }
                guard recycleError == nil else {
                    let detail = recycleError?.localizedDescription ?? "Unknown error"
                    Log.app.error("Failed to move Chap to Trash: \(detail, privacy: .public)")
                    let failureAlert = NSAlert()
                    failureAlert.messageText = "Could not uninstall Chap"
                    failureAlert.informativeText =
                        "Chap was not moved to the Trash. Your settings were kept.\n\nError: \(detail)"
                    failureAlert.alertStyle = .warning
                    failureAlert.addButton(withTitle: "OK")
                    failureAlert.runModal()
                    return
                }

                // 앱이 휴지통으로 옮겨진 뒤에만 로그인 항목, 권한, 설정을 정리한다.
                self.applyLoginItem(enabled: false)
                self.resetAppleEventsPermission()
                do {
                    try AppLifecycleSupport.removeConfigurationFiles(configPath: self.configPath)
                } catch {
                    Log.config.error(
                        "Failed to remove config during uninstall: \(error.localizedDescription, privacy: .public)"
                    )
                    let cleanupAlert = NSAlert()
                    cleanupAlert.messageText = "Chap moved to Trash"
                    cleanupAlert.informativeText =
                        "Some settings could not be removed. Delete these files manually:\n\(self.configPath)\n\(self.configPath).bak\n\nError: \(error.localizedDescription)"
                    cleanupAlert.alertStyle = .warning
                    cleanupAlert.addButton(withTitle: "OK")
                    cleanupAlert.runModal()
                }
                NSApp.terminate(nil)
            }
        }
    }

    private func resetAppleEventsPermission() {
        let resetTask = Process()
        resetTask.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        resetTask.arguments = [
            "reset", "AppleEvents", Bundle.main.bundleIdentifier ?? "com.mingyupark.Chap",
        ]
        do {
            try resetTask.run()
            resetTask.waitUntilExit()
            if resetTask.terminationStatus != 0 {
                Log.app.warning(
                    "AppleEvents permission reset exited with status \(resetTask.terminationStatus, privacy: .public)"
                )
            }
        } catch {
            Log.app.warning(
                "Failed to reset AppleEvents permission: \(error.localizedDescription, privacy: .public)"
            )
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
