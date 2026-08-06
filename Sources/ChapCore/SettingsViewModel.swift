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

    public var hasChanges: Bool {
        sites != originalSites || showGuideWindow != originalGuide
            || launchAtLogin != originalLogin
    }

    public func markSaved() {
        originalSites = sites
        originalGuide = showGuideWindow
        originalLogin = launchAtLogin
    }

    public init(
        sites: [Site], showGuideWindow: Bool = true,
        launchAtLogin: Bool = false
    ) {
        self.sites = sites
        self.showGuideWindow = showGuideWindow
        self.launchAtLogin = launchAtLogin
        self.originalSites = sites
        self.originalGuide = showGuideWindow
        self.originalLogin = launchAtLogin
    }
}
