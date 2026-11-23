import Cocoa

// MARK: - Timer (메뉴·노치 카운트다운)

extension AppDelegate {
    /// 메뉴의 Timer ▸. 꺼져 있으면 길이 목록, 돌고 있으면 Stop Timer가 맨 위에 온다.
    func addTimerMenu(to menu: NSMenu) {
        let item = NSMenuItem(
            title: TimerPolicy.menuTitle(end: chapTimer.endDate, now: Date()), action: nil,
            keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        if chapTimer.isRunning {
            let stop = NSMenuItem(
                title: "Stop Timer", action: #selector(stopTimerFromMenu), keyEquivalent: "")
            stop.target = self
            submenu.addItem(stop)
            submenu.addItem(.separator())
        }
        for (index, length) in TimerPolicy.presets.enumerated() {
            let preset = NSMenuItem(
                title: TimerPolicy.presetTitle(length), action: #selector(startTimerFromMenu(_:)),
                keyEquivalent: "")
            preset.tag = index
            preset.target = self
            submenu.addItem(preset)
        }
        item.submenu = submenu
        menu.addItem(item)
        timerMenuItem = item
    }

    @objc private func startTimerFromMenu(_ sender: NSMenuItem) {
        guard TimerPolicy.presets.indices.contains(sender.tag) else { return }
        chapTimer.start(length: TimerPolicy.presets[sender.tag])
    }

    @objc private func stopTimerFromMenu() {
        chapTimer.stop()
    }

    /// 시작·중지는 메뉴와 노치 배지를 바꾸고 노치를 한 번 빛낸다. 다 되면 소리와 HUD로도 알린다.
    func handleTimerEvent(_ event: ChapTimerController.Event) {
        if event == .finished {
            NSSound(named: "Glass")?.play()
            KeepAwakeHUD.show(
                message: TimerPolicy.finishedMessage, focusOn: true, anyScreen: true)
        }
        buildMenu()
        notchLauncher.updateTimerBadge()
        // 배지를 붙이거나 뗀 뒤에 빛내야 빛이 지금 배지까지 감싼다.
        switch event {
        case .started: flashNotchGlow(.started)
        case .stopped: flashNotchGlow(.ended)
        // 소리를 꺼 두어도 눈에 들어오게 가장 밝고 길게 빛난다.
        case .finished: flashNotchGlow(.timerFinished)
        }
    }
}
