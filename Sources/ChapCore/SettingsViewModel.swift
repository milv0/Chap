import Foundation

public struct SettingsPayload {
    public let sites: [Site]
    public let showGuideWindow: Bool
    public let launchAtLogin: Bool
}

public final class SettingsViewModel: ObservableObject {
    @Published public var sites: [Site]
    @Published public var showGuideWindow: Bool
    @Published public var launchAtLogin: Bool
    @Published public var originalSites: [Site]
    @Published public var originalGuide: Bool
    @Published public var originalLogin: Bool
    /// 저장 성공 시 true를 반환해야 함. 실패(false) 시 markSaved가 호출되지 않음.
    public var onSave: ((SettingsPayload) -> Bool)?
    private let saveDebouncer: SaveDebouncer

    public var hasChanges: Bool {
        sites != originalSites || showGuideWindow != originalGuide
            || launchAtLogin != originalLogin
    }

    public func markSaved() {
        originalSites = sites
        originalGuide = showGuideWindow
        originalLogin = launchAtLogin
    }

    /// 유효한 현재 편집 상태를 debounce해 자동 저장한다.
    public func scheduleAutoSave() {
        saveDebouncer.schedule { [weak self] in
            guard let self else { return }
            let config = Config(
                showGuideWindow: self.showGuideWindow,
                launchAtLogin: self.launchAtLogin,
                sites: self.sites)
            guard validateConfig(config).isValid else { return }
            _ = self.persistCurrentState()
        }
    }

    public func flushPendingSave() {
        saveDebouncer.flush()
    }

    public func cancelPendingSave() {
        saveDebouncer.cancel()
    }

    @discardableResult
    public func persistCurrentState() -> Bool {
        let saved =
            onSave?(
                SettingsPayload(
                    sites: sites, showGuideWindow: showGuideWindow,
                    launchAtLogin: launchAtLogin)) ?? true
        if saved { markSaved() }
        return saved
    }

    public init(
        sites: [Site], showGuideWindow: Bool = true,
        launchAtLogin: Bool = false,
        saveDebouncer: SaveDebouncer = SaveDebouncer()
    ) {
        self.sites = sites
        self.showGuideWindow = showGuideWindow
        self.launchAtLogin = launchAtLogin
        self.originalSites = sites
        self.originalGuide = showGuideWindow
        self.originalLogin = launchAtLogin
        self.saveDebouncer = saveDebouncer
    }
}
