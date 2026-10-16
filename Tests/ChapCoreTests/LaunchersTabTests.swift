import Foundation
import Testing

@testable import Chap

@Suite("Launchers tab slot")
struct LaunchersTabTests {
    private func site(_ name: String, _ type: LaunchType) -> Site {
        Site(
            name: name, url: "https://example.com/\(name)", width: 800, height: 600,
            launchType: type, appPath: "/Applications/\(name).app", folderPath: "~/\(name)")
    }

    @Test("one Launchers slot holds every type that has items, in launch type order")
    func slotHoldsTypesWithItems() {
        let sites = [site("Finder", .finder), site("Docs", .url)]

        let slots = NotchSlotContent.slots(widgets: [.none, .none, .launchers], sites: sites)

        #expect(slots.count == 1)
        guard case .launcherTabs(let sections) = slots.first else {
            Issue.record("expected a Launchers slot")
            return
        }
        #expect(sections.map(\.launchType) == [.url, .finder])
    }

    @Test("with no launchers at all, the slot is left out")
    func emptyLaunchersIsSkipped() {
        #expect(NotchSlotContent.slots(widgets: [.none, .none, .launchers], sites: []).isEmpty)
    }

    @Test("Launchers is a placeable widget that round-trips")
    func widgetRoundTrips() throws {
        let config = try JSONDecoder().decode(
            Config.self, from: Data(#"{"notchWidgets": ["launchers"], "sites": []}"#.utf8))
        #expect(config.notchWidgets == [.none, .none, .launchers, .none, .none, .none])
        #expect(NotchWidget.launchers.launchType == nil)
        #expect(NotchWidget.launchers.fits(slot: 2))
        #expect(!NotchWidget.launchers.fits(slot: 0))
    }

    @Test("with Launchers in one slot, every other widget fits in the six slots")
    func everyWidgetFits() {
        let all: [NotchWidget] = [
            .screenshots, .downloads, .launchers, .awake, .todo, .workspaces,
        ]
        #expect(NotchWidget.normalizedSlots(all) == all)
    }

    @Test("the tab remembers the last type, falling back to the first one with items")
    func selectedTab() {
        #expect(LauncherListPolicy.selectedTab(stored: "app", available: [.url, .app]) == .app)
        #expect(LauncherListPolicy.selectedTab(stored: "app", available: [.url, .finder]) == .url)
        #expect(LauncherListPolicy.selectedTab(stored: nil, available: [.finder]) == .finder)
        #expect(LauncherListPolicy.selectedTab(stored: "nope", available: [.app]) == .app)
        #expect(LauncherListPolicy.selectedTab(stored: "url", available: []) == nil)
    }

    @Test("the slot is roomier than a single list slot")
    func roomyWidth() {
        #expect(
            LauncherListPolicy.launcherTabsColumnWidth
                > LauncherListPolicy.listColumnWidthRange.upperBound)
        #expect(LauncherListPolicy.title(for: .url) == "Sites")
        #expect(LauncherListPolicy.title(for: .app) == "Apps")
        #expect(LauncherListPolicy.title(for: .finder) == "Finder")
    }
}
