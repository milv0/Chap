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

    /// 시작·중지는 조용히 메뉴와 노치 배지만 바꾼다. 끝나면 소리와 HUD로 알린다.
    func handleTimerEvent(_ event: ChapTimerController.Event) {
        if event == .finished {
            NSSound(named: "Glass")?.play()
            KeepAwakeHUD.show(
                message: TimerPolicy.finishedMessage, focusOn: true, anyScreen: true)
        }
        buildMenu()
        notchLauncher.updateTimerBadge()
    }
}
