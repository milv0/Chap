import Testing

@testable import Chap

@Suite("MenuConfigurationSnapshot")
struct MenuConfigurationSnapshotTests {
    private func site(
        name: String = "A", url: String = "https://a.com", width: Int = 800,
        shortcut: String? = "A"
    ) -> Site {
        Site(
            name: name, url: url, width: width, height: 600,
            launchType: .url, shortcut: shortcut)
    }

    @Test("window and target changes do not require menu rebuild")
    func ignoresNonMenuFields() {
        let first = site()
        var changed = first
        changed.width = 1200
        changed.url = "https://changed.com"
        changed.displayName = "Other Display"

        #expect(
            MenuConfigurationSnapshot(sites: [first])
                == MenuConfigurationSnapshot(sites: [changed]))
    }

    @Test("name type shortcut and order changes require rebuild")
    func detectsRelevantChanges() {
        let first = site(name: "First", shortcut: "F")
        let second = site(name: "Second", shortcut: "S")

        var renamed = first
        renamed.name = "Renamed"
        #expect(
            MenuConfigurationSnapshot(sites: [first]) != MenuConfigurationSnapshot(sites: [renamed])
        )

        var retyped = first
        retyped.launchType = .app
        #expect(
            MenuConfigurationSnapshot(sites: [first]) != MenuConfigurationSnapshot(sites: [retyped])
        )

        var shortcutChanged = first
        shortcutChanged.shortcut = "X"
        #expect(
            MenuConfigurationSnapshot(sites: [first])
                != MenuConfigurationSnapshot(sites: [shortcutChanged]))

        #expect(
            MenuConfigurationSnapshot(sites: [first, second])
                != MenuConfigurationSnapshot(sites: [second, first]))
    }
}
