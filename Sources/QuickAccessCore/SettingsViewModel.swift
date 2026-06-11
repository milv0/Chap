import Foundation

public final class SettingsViewModel: ObservableObject {
    @Published public var sites: [Site]
    @Published public var runInBackground: Bool
    @Published public var alwaysCenter: Bool
    @Published public var originalSites: [Site]
    @Published public var originalBg: Bool
    @Published public var originalAlwaysCenter: Bool
    public var onSave: (([Site], Bool, Bool) -> Void)?
    public var onReload: (() -> Void)?

    public var hasChanges: Bool {
        sites != originalSites || runInBackground != originalBg || alwaysCenter != originalAlwaysCenter
    }

    public func markSaved() {
        originalSites = sites
        originalBg = runInBackground
        originalAlwaysCenter = alwaysCenter
    }

    public init(sites: [Site], runInBackground: Bool, alwaysCenter: Bool) {
        self.sites = sites
        self.runInBackground = runInBackground
        self.alwaysCenter = alwaysCenter
        self.originalSites = sites
        self.originalBg = runInBackground
        self.originalAlwaysCenter = alwaysCenter
    }
}
