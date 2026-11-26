import Cocoa

// MARK: - Notch Glow

extension AppDelegate {
    /// 노치를 한 번 빛낸다(Keep Awake·Timer 시작과 끝, Timer가 다 됨, 새 파일, 창이 제자리에 맞춰짐).
    /// Notch Glow·노치 런처가 켜져 있고 가림막이 없을 때만. 새 파일·창 맞춤은 각각 따로 끌 수 있다.
    /// 도커가 펼쳐져 있으면 도커가 노치를 덮으므로 도커 위쪽 검정 띠 테두리를 두르고, 접혀 있으면 노치와 옆 배지를 두른다.
    func flashNotchGlow(_ moment: NotchGlowMoment) {
        guard !isRunningTests, config.notchGlowEnabled, config.notchLauncherEnabled,
            !coverScreensController.isOn
        else { return }
        switch moment {
        case .arrival: guard config.notchGlowArrivals else { return }
        case .snap: guard config.notchGlowSnaps else { return }
        case .preview, .started, .ended, .timerFinished: break
        }
        // 노치 빛이라 노치가 있는 화면에서만(접힌 노치 빛과 같다).
        guard NotchLauncherController.notchScreen() != nil else { return }
        if notchLauncher.flashStripGlow(palette: config.notchGlowPalette, moment: moment) {
            return
        }
        NotchBeamFlash.show(
            palette: config.notchGlowPalette, moment: moment, around: notchLauncher.glowOutline())
    }

    // MARK: Arrivals

    /// 새 스크린샷·다운로드를 지켜볼 폴더를 설정에 맞춘다. 그 선반이 노치에 놓여 있을 때만 지켜본다
    /// (놓이지 않은 선반의 폴더는 열지 않아, 그 때문에 macOS 폴더 접근 허락을 새로 묻지 않는다).
    /// Chap Drop은 빛나지 않는다: 파일을 끌어오는 동안 도커 테두리가 이미 빛나, 놓은 뒤 또 빛나면 겹친다.
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
