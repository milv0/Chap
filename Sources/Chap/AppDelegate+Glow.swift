import Cocoa

// MARK: - Notch Glow

extension AppDelegate {
    /// 노치를 한 번 빛낸다(Keep Awake·Timer 시작과 끝, Timer가 다 됨, 새 파일, 창이 제자리에 맞춰짐).
    /// Notch Glow·노치 런처가 켜져 있고 가림막이 없을 때만. 새 파일·창 맞춤은 각각 따로 끌 수 있다.
    /// 도커가 열려 있으면 도커가 노치를 덮는다. Keep Awake·Timer는 도커에서 켜고 끄는 일이 많아, 그 순간은 도커가
    /// 닫힐 때 빛내고(`notchPanelVisibilityChanged`), 나머지는 건너뛴다.
    func flashNotchGlow(_ moment: NotchGlowMoment) {
        guard !isRunningTests, config.notchGlowEnabled, config.notchLauncherEnabled,
            !coverScreensController.isOn
        else { return }
        switch moment {
        case .arrival: guard config.notchGlowArrivals else { return }
        case .snap: guard config.notchGlowSnaps else { return }
        case .preview, .started, .ended, .timerFinished: break
        }
        guard !notchLauncher.isPanelOpen else {
            switch moment {
            case .started, .ended, .timerFinished: pendingNotchGlow = (moment, Date())
            case .preview, .arrival, .snap: break
            }
            return
        }
        pendingNotchGlow = nil
        NotchBeamFlash.show(
            palette: config.notchGlowPalette, moment: moment, around: notchLauncher.glowOutline())
    }

    /// 도커가 닫히면, 열려 있는 동안 미뤄 둔 순간을 빛낸다. 오래 열어 둔 뒤라면(30초 넘게) 늦은 빛은 버린다.
    func notchPanelVisibilityChanged(isOpen: Bool) {
        guard !isOpen, let pending = pendingNotchGlow else { return }
        pendingNotchGlow = nil
        guard Date().timeIntervalSince(pending.since) < 30 else { return }
        // 도커가 접히며 Drop·Timer 배지가 다시 붙은 뒤에 둘레를 잰다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.flashNotchGlow(pending.moment)
        }
    }

    // MARK: Arrivals

    /// 새 스크린샷·다운로드를 지켜볼 폴더를 설정에 맞춘다. 그 선반이 노치에 놓여 있을 때만 지켜본다
    /// (놓이지 않은 선반의 폴더는 열지 않아, 그 때문에 macOS 폴더 접근 허락을 새로 묻지 않는다).
    /// Drop은 Chap이 직접 넣으므로 알림만 받는다.
    func refreshArrivalWatchers() {
        guard !isRunningTests else { return }
        let watches =
            config.notchGlowEnabled && config.notchGlowArrivals && config.notchLauncherEnabled
            && NotchLauncherController.notchScreen() != nil
        let placed = Set(config.notchWidgets)
        screenshotFolderWatcher = folderWatcher(
            screenshotFolderWatcher, enabled: watches && placed.contains(.screenshots),
            url: ScreenshotShelf.directory()
        ) { [weak self] in self?.checkScreenshotArrival() }
        downloadsFolderWatcher = folderWatcher(
            downloadsFolderWatcher, enabled: watches && placed.contains(.downloads),
            url: DownloadsShelf.directory()
        ) { [weak self] in self?.checkDownloadArrival() }
        if dropAddObserver == nil {
            dropAddObserver = NotificationCenter.default.addObserver(
                forName: ChapDrop.didAddNotification, object: nil, queue: .main
            ) { [weak self] _ in
                // 노치·배지에 놓으면 도커가 닫힌 뒤에 빛나게 잠깐 기다린다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self?.flashNotchGlow(.arrival)
                }
            }
        }
    }

    /// 지켜보는 폴더를 바꾸거나 멈춘다. 처음 지켜볼 때는 지금 가장 새 파일을 기억해 둬, 그 파일로 빛나지 않게 한다.
    private func folderWatcher(
        _ current: FolderChangeWatcher?, enabled: Bool, url: URL,
        onChange: @escaping () -> Void
    ) -> FolderChangeWatcher? {
        guard enabled else {
            current?.stop()
            return nil
        }
        if let current, current.url.standardizedFileURL == url.standardizedFileURL {
            return current
        }
        current?.stop()
        onChange()
        return FolderChangeWatcher(url: url, onChange: onChange)
    }

    private func checkScreenshotArrival() {
        let previous = ScreenshotShelf.lastKnownNewest
        ScreenshotShelf.recentScreenshotsAsync { [weak self] _ in
            guard
                NotchGlowPolicy.isNewArrival(
                    previous: previous, newest: ScreenshotShelf.lastKnownNewest, now: Date())
            else { return }
            self?.flashNotchGlow(.arrival)
        }
    }

    private func checkDownloadArrival() {
        let previous = DownloadsShelf.lastKnownNewest
        DownloadsShelf.newestDownloadAsync { [weak self] newest in
            guard NotchGlowPolicy.isNewArrival(previous: previous, newest: newest, now: Date())
            else { return }
            self?.flashNotchGlow(.arrival)
        }
    }
}
