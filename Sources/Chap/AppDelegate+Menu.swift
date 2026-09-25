import Cocoa
import SwiftUI

// MARK: - Menu, hotkeys, status item

extension AppDelegate {
    // NSMenuDelegate — 메뉴바 메뉴가 열릴 때 권한 재확인
    @objc func keepAwakeActivate(_ sender: NSMenuItem) {
        guard KeepAwakePolicy.presets.indices.contains(sender.tag) else { return }
        keepAwake.activate(preset: KeepAwakePolicy.presets[sender.tag])
    }

    @objc func keepAwakeTurnOff() {
        keepAwake.deactivate()
    }

    /// Keep Awake 상태 변화 피드백: 사운드 + 중앙 커피 HUD + 메뉴 재구성.
    func handleKeepAwakeEvent(_ event: KeepAwakeController.Event) {
        switch event {
        case .started(let presetTitle):
            NSSound(named: "Purr")?.play()
            KeepAwakeHUD.show(
                message: KeepAwakePolicy.hudMessage(startedPresetTitle: presetTitle),
                symbolName: "cup.and.saucer.fill")
        case .ended:
            NSSound(named: "Pop")?.play()
            KeepAwakeHUD.show(
                message: KeepAwakePolicy.hudMessageEnded,
                symbolName: "cup.and.saucer")
        }
        buildMenu()
        updateStatusIcon(accessible: accessibilityController.isAccessible)
    }

    func menuWillOpen(_ menu: NSMenu) {
        accessibilityController.refresh(reason: "menu", showAlert: false)
        keepAwakeMenuItem?.title = KeepAwakePolicy.menuTitle(
            sessionEnd: keepAwake.sessionEnd, now: Date())
    }

    /// 상태바 아이콘. 권한이 없으면 경고 배지 심볼, 있으면 사용자가 선택한 아이콘.
    /// Keep Awake 활성 중이면 선택된 아이콘을 테마 블루로 전환해 상태를 표시한다.
    func statusIconImage(accessible: Bool) -> NSImage? {
        statusIconImage(
            accessible: accessible, choice: config.statusBarIcon,
            keepAwakeActive: keepAwake.isActive)
    }

    /// `choice`에 따라 상태바 아이콘을 결정한다. 권한이 없으면 항상 경고 심볼.
    /// `keepAwakeActive`는 두 아이콘 모두에 적용된다: Default는 커스텀 PNG의 알파
    /// 마스크를 테마 블루로 틴트하고, Lightning은 심볼을 테마 블루로 렌더링한다.
    func statusIconImage(
        accessible: Bool, choice: StatusBarIconChoice, keepAwakeActive: Bool = false
    ) -> NSImage? {
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
                guard keepAwakeActive else {
                    icon.isTemplate = true
                    return icon
                }
                return Self.accentTintedStatusBarImage(
                    icon, accessibilityDescription: "Chap – Keep Awake active")
            }
            // 리소스 누락 시 심볼 폴백
            if keepAwakeActive {
                return Self.accentStatusBarSymbolImage(
                    name: "bolt.fill",
                    accessibilityDescription: "Chap – Keep Awake active")
            }
            return Self.statusBarSymbolImage(
                name: "bolt.fill", accessibilityDescription: "Chap")
        case .lightning:
            guard keepAwakeActive else {
                return Self.statusBarSymbolImage(
                    name: "bolt.fill", accessibilityDescription: "Chap")
            }
            return Self.accentStatusBarSymbolImage(
                name: "bolt.fill",
                accessibilityDescription: "Chap – Keep Awake active")
        }
    }

    /// 앱 테마 색 (DS.accent와 동일).
    private static let accentColor = NSColor(
        red: 54 / 255, green: 100 / 255, blue: 255 / 255, alpha: 1)

    /// `statusBarSymbolImage`와 동일한 geometry로, 색만 테마 블루로 고정한
    /// non-template 이미지를 만든다. 크기·baseline이 template 버전과 동일하도록
    /// SymbolConfiguration에 색을 먼저 합성한 뒤 그려서 착시 없는 전환을 보장한다.
    static func accentStatusBarSymbolImage(
        name: String, accessibilityDescription: String?
    ) -> NSImage? {
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [accentColor])
        let config = sizeConfig.applying(colorConfig)
        guard
            let symbol = NSImage(
                systemSymbolName: name,
                accessibilityDescription: accessibilityDescription)?
                .withSymbolConfiguration(config)
        else { return nil }
        symbol.isTemplate = false

        let canvas = NSSize(width: 22, height: 22)
        let image = NSImage(size: canvas)
        image.lockFocus()
        let rect = NSRect(
            x: (canvas.width - symbol.size.width) / 2,
            y: (canvas.height - symbol.size.height) / 2,
            width: symbol.size.width, height: symbol.size.height)
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// Default PNG 아이콘의 알파 마스크를 테마 블루로 틴트한다.
    /// 원본과 동일한 22×22 canvas를 사용해 Keep Awake 시작/종료 시 geometry가 변하지 않는다.
    static func accentTintedStatusBarImage(
        _ source: NSImage, accessibilityDescription: String?
    ) -> NSImage? {
        let size = source.size
        guard size.width > 0, size.height > 0 else { return nil }

        let image = NSImage(size: size)
        image.lockFocus()
        source.draw(
            in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        accentColor.setFill()
        NSRect(origin: .zero, size: size).fill(using: .sourceIn)
        image.unlockFocus()
        image.isTemplate = false
        image.accessibilityDescription = accessibilityDescription
        return image
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
        // 목록 구성은 ChapCore 정책이 단독 기준이다. 노치 패널도 같은 정책을 쓴다.
        let sections = LauncherListPolicy.sections(
            sites: config.sites, hiddenLaunchTypes: config.hiddenMenuLaunchTypes)
        var addedSiteItem = false
        for (sectionIndex, section) in sections.enumerated() {
            // 타입이 바뀌면 구분선 추가
            if sectionIndex > 0 {
                menu.addItem(.separator())
            }
            for entry in section.entries {
                let site = entry.site
                let keyEquiv =
                    config.optionShortcutsEnabled ? site.shortcut?.lowercased() ?? "" : ""
                let item = NSMenuItem(
                    title: site.name, action: #selector(openSite(_:)), keyEquivalent: keyEquiv)
                if !keyEquiv.isEmpty {
                    item.keyEquivalentModifierMask = .option
                }
                item.image = NSImage(
                    systemSymbolName: LauncherListPolicy.symbolName(for: section.launchType),
                    accessibilityDescription: nil)
                item.tag = entry.siteIndex
                item.target = self
                menu.addItem(item)
                addedSiteItem = true
            }
        }
        if addedSiteItem {
            menu.addItem(.separator())
        }

        // Keep Mac Awake — 화면 잠자기 방지 세션 (세션 한정, config 미저장)
        let keepAwakeItem = NSMenuItem(
            title: KeepAwakePolicy.menuTitle(sessionEnd: keepAwake.sessionEnd, now: Date()),
            action: nil, keyEquivalent: "")
        keepAwakeItem.image = NSImage(
            systemSymbolName: "cup.and.saucer.fill",
            accessibilityDescription: "Keep Mac Awake")
        let keepAwakeMenu = NSMenu()
        if keepAwake.isActive {
            let turnOff = NSMenuItem(
                title: "Turn Off", action: #selector(keepAwakeTurnOff), keyEquivalent: "")
            turnOff.target = self
            keepAwakeMenu.addItem(turnOff)
            keepAwakeMenu.addItem(.separator())
        }
        for (index, preset) in KeepAwakePolicy.presets.enumerated() {
            let presetItem = NSMenuItem(
                title: preset.title, action: #selector(keepAwakeActivate(_:)),
                keyEquivalent: "")
            presetItem.tag = index
            presetItem.target = self
            keepAwakeMenu.addItem(presetItem)
        }
        keepAwakeItem.submenu = keepAwakeMenu
        menu.addItem(keepAwakeItem)
        keepAwakeMenuItem = keepAwakeItem
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
        menu.addItem(.separator())

        // Check for Updates — disabled when Sparkle configuration is incomplete
        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = updateController.canCheckForUpdates
        menu.addItem(updateItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        menu.delegate = self
        statusItem.menu = menu
        configureGlobalHotKeys()
        refreshNotchLauncher()
    }

    /// 노치 런처를 최신 config로 동기화한다. 메뉴와 같은 목록 정책을 쓰므로
    /// 숨긴 섹션·순서가 항상 일치한다. 테스트에서는 창을 만들지 않는다.
    func refreshNotchLauncher() {
        guard !isRunningTests else { return }
        notchLauncher.slotsProvider = { [weak self] in
            guard let self else { return [] }
            // 위젯 배치는 사용자가 명시적으로 고른 것이므로 메뉴의 숨김
            // 설정과 무관하게 모든 launch type 섹션에서 고른다.
            let sections = LauncherListPolicy.sections(
                sites: self.config.sites, hiddenLaunchTypes: [])
            return self.config.notchWidgets.compactMap { widget in
                switch widget {
                case .none:
                    return nil
                case .screenshots:
                    return .screenshots(ScreenshotShelf.recentScreenshots())
                case .drop:
                    return .drop
                case .sites, .apps, .folders, .scripts:
                    // 해당 타입의 런처가 없으면 칸을 건너뛴다.
                    return sections.first { $0.launchType == widget.launchType }
                        .map(NotchSlotContent.launchers)
                }
            }
        }
        notchLauncher.styleProvider = { [weak self] in
            self?.config.notchPanelStyle ?? .black
        }
        notchLauncher.opacityProvider = { [weak self] in
            self?.config.notchPanelOpacity ?? Config.notchPanelOpacityDefault
        }
        notchLauncher.colorProvider = { [weak self] in
            self?.config.notchPanelColorHex ?? Config.notchPanelColorHexDefault
        }
        notchLauncher.awakeActiveProvider = { [weak self] in
            self?.keepAwake.isActive ?? false
        }
        notchLauncher.awakeSessionEndProvider = { [weak self] in
            self?.keepAwake.sessionEnd
        }
        notchLauncher.onLaunch = { [weak self] index in
            guard let self, index >= 0, index < self.config.sites.count else { return }
            self.launchSite(self.config.sites[index])
        }
        notchLauncher.update(enabled: config.notchLauncherEnabled)
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
