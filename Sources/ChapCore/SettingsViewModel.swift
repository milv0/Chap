import Foundation

public final class SettingsViewModel: ObservableObject {
    @Published public var sites: [Site]
    @Published public var runInBackground: Bool
    @Published public var showGhostWindow: Bool
    @Published public var launchAtLogin: Bool
    @Published public var originalSites: [Site]
    @Published public var originalBg: Bool
    @Published public var originalGhost: Bool
    @Published public var originalLogin: Bool
    public var onSave: (([Site], Bool, Bool, Bool) -> Void)?
    public var onReload: (() -> Void)?

    public var hasChanges: Bool {
        sites != originalSites || runInBackground != originalBg
            || showGhostWindow != originalGhost || launchAtLogin != originalLogin
    }

    public func markSaved() {
        originalSites = sites
        originalBg = runInBackground
        originalGhost = showGhostWindow
        originalLogin = launchAtLogin
    }

    public init(
        sites: [Site], runInBackground: Bool, showGhostWindow: Bool = true,
        launchAtLogin: Bool = false
    ) {
        self.sites = sites
        self.runInBackground = runInBackground
        self.showGhostWindow = showGhostWindow
        self.launchAtLogin = launchAtLogin
        self.originalSites = sites
        self.originalBg = runInBackground
        self.originalGhost = showGhostWindow
        self.originalLogin = launchAtLogin
    }
}
