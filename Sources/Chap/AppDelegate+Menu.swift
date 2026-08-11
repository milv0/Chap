import Cocoa
import SwiftUI

// MARK: - Menu, hotkeys, status item

extension AppDelegate {
    // NSMenuDelegate — 메뉴바 메뉴가 열릴 때 권한 재확인
    func menuWillOpen(_ menu: NSMenu) {
        accessibilityController.refresh(reason: "menu", showAlert: false)
    }

    /// 상태바 아이콘. 권한이 있으면 커스텀 템플릿 아이콘, 없으면 경고 배지 심볼.
    func statusIconImage(accessible: Bool) -> NSImage? {
        if accessible, let icon = NSImage(named: "StatusBarIcon") {
            icon.isTemplate = true
            icon.size = NSSize(width: 22, height: 22)
            return icon
        }
        let iconName = accessible ? "bolt.fill" : "bolt.trianglebadge.exclamationmark"
        return NSImage(systemSymbolName: iconName, accessibilityDescription: "Chap")
    }

    func updateStatusIcon(accessible: Bool) {
        DispatchQueue.main.async {
            self.statusItem.button?.image = self.statusIconImage(accessible: accessible)
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

    @objc func reportBug() {
        if let url = URL(string: "https://github.com/milv0/Chap/issues/new") {
            NSWorkspace.shared.open(url)
        }
    }
}
