import Cocoa
import SwiftUI

// MARK: - Menu, hotkeys, status item

extension AppDelegate {
    // NSMenuDelegate — 메뉴바 메뉴가 열릴 때 권한 재확인
    func menuWillOpen(_ menu: NSMenu) {
        accessibilityController.refresh(reason: "menu", showAlert: false)
    }

    /// 상태바 아이콘. 권한이 없으면 경고 배지 심볼, 있으면 사용자가 선택한 아이콘.
    func statusIconImage(accessible: Bool) -> NSImage? {
        statusIconImage(accessible: accessible, choice: config.statusBarIcon)
    }

    /// `choice`에 따라 상태바 아이콘을 결정한다. 권한이 없으면 항상 경고 심볼.
    func statusIconImage(accessible: Bool, choice: StatusBarIconChoice) -> NSImage? {
        guard accessible else {
            return Self.statusBarSymbolImage(
                name: "bolt.trianglebadge.exclamationmark",
                accessibilityDescription: "Chap – accessibility required")
        }
        switch choice {
        case .default:
            if let icon = Self.isolatedCopy(
                of: NSImage(named: "StatusBarIcon"),
                size: NSSize(width: 22, height: 22))
            {
                icon.isTemplate = true
                return icon
            }
            // 리소스 누락 시 심볼 폴백
            return Self.statusBarSymbolImage(
                name: "bolt.fill", accessibilityDescription: "Chap")
        case .lightning:
            return Self.statusBarSymbolImage(
                name: "bolt.fill", accessibilityDescription: "Chap")
        }
    }

    /// Named 이미지의 독립적인 복사본을 생성하여 원본 캐시를 오염시키지 않는다.
    /// AppKit의 `NSImage(named:)`는 캐시된 공유 인스턴스를 반환할 수 있으므로,
    /// 크기를 변경하기 전에 반드시 copy해야 다른 사용처에 영향을 주지 않는다.
    static func isolatedCopy(of source: NSImage?, size: NSSize) -> NSImage? {
        guard let source else { return nil }
        guard let copied = source.copy() as? NSImage else { return nil }
        copied.size = size
        return copied
    }

    /// 상태바에 사용할 SF Symbol 이미지를 고정된 geometry로 생성한다.
    /// 명시적 pointSize/weight + isTemplate + 22×22 캔버스로 첫 프레임부터
    /// 안정된 크기를 보장한다.
    static func statusBarSymbolImage(
        name: String, accessibilityDescription: String?
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard
            let image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: accessibilityDescription)?
                .withSymbolConfiguration(config)
        else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 22, height: 22)
        return image
    }

    func updateStatusIcon(accessible: Bool) {
        DispatchQueue.main.async {
            self.statusItem.button?.image = self.statusIconImage(accessible: accessible)
        }
    }

    func buildMenu() {
        ChromeLauncher.configureWindowReuse(sites: config.sites)
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
            let keyEquiv =
                config.optionShortcutsEnabled ? site.shortcut?.lowercased() ?? "" : ""
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
            title: "Settings...", action: #selector(openSettings),
            keyEquivalent: config.optionShortcutsEnabled ? "," : "")
        if config.optionShortcutsEnabled {
            settings.keyEquivalentModifierMask = .option
        }
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

        // Check for Updates — disabled when Sparkle configuration is incomplete
        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = updateController.canCheckForUpdates
        menu.addItem(updateItem)

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
        globalHotKeyManager.configure(
            sites: config.sites,
            optionShortcutsEnabled: config.optionShortcutsEnabled
        ) { [weak self] action in
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
        let window = makeManagedWindow(
            title: "Chap Q&A", contentSize: NSSize(width: 1120, height: 900),
            styleMask: [.titled, .closable, .resizable],
            minSize: NSSize(width: 400, height: 400))
        window.contentViewController = NSHostingController(rootView: QAView())
        window.center()
        presentManagedWindow(window)
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

    @objc func checkForUpdates(_ sender: Any?) {
        updateController.checkForUpdates(sender)
    }

    @objc func reportBug() {
        if let url = URL(string: "https://github.com/milv0/Chap/issues/new") {
            NSWorkspace.shared.open(url)
        }
    }
}
