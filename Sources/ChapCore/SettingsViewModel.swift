import Foundation

public final class SettingsViewModel: ObservableObject {
    @Published public var sites: [Site]
    @Published public var runInBackground: Bool
    @Published public var showGhostWindow: Bool
    @Published public var originalSites: [Site]
    @Published public var originalBg: Bool
    @Published public var originalGhost: Bool
    public var onSave: (([Site], Bool, Bool) -> Void)?
    public var onReload: (() -> Void)?

    public var hasChanges: Bool {
        sites != originalSites || runInBackground != originalBg || showGhostWindow != originalGhost
    }

    public func markSaved() {
        originalSites = sites
        originalBg = runInBackground
        originalGhost = showGhostWindow
    }

    public init(sites: [Site], runInBackground: Bool, showGhostWindow: Bool = true) {
        self.sites = sites
        self.runInBackground = runInBackground
        self.showGhostWindow = showGhostWindow
        self.originalSites = sites
        self.originalBg = runInBackground
        self.originalGhost = showGhostWindow
    }
}
