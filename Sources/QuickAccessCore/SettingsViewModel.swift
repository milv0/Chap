import Foundation

public final class SettingsViewModel: ObservableObject {
    @Published public var sites: [Site]
    @Published public var runInBackground: Bool
    @Published public var originalSites: [Site]
    @Published public var originalBg: Bool
    public var onSave: (([Site], Bool) -> Void)?
    public var onReload: (() -> Void)?

    public var hasChanges: Bool {
        sites != originalSites || runInBackground != originalBg
    }

    public func markSaved() {
        originalSites = sites
        originalBg = runInBackground
    }

    public init(sites: [Site], runInBackground: Bool) {
        self.sites = sites
        self.runInBackground = runInBackground
        self.originalSites = sites
        self.originalBg = runInBackground
    }
}
