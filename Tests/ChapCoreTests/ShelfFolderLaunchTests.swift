import Testing

@testable import Chap

@Suite("ShelfFolderLaunch – shelf title opens a centered Standard Finder window")
struct ShelfFolderLaunchTests {
    @Test("the folder opens as a Finder launch with the Standard preset")
    func standardFinderLaunch() {
        let site = ShelfFolderLaunch.site(name: "Downloads", folderPath: "/Users/me/Downloads")
        #expect(site.launchType == .finder)
        #expect(site.folderPath == "/Users/me/Downloads")
        #expect(site.windowSizePreset == "standard")
        #expect(ShelfFolderLaunch.presetID == "standard")
    }

    @Test("no display is pinned, so the window centers on the cursor screen")
    func followsCursorScreen() {
        let site = ShelfFolderLaunch.site(name: "Screenshots", folderPath: "/tmp")
        #expect(site.displayName == nil)
        #expect(site.displayIdentifier == nil)
        #expect(site.shortcut == nil)
    }
}
