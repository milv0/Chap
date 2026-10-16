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

    @Test("the slot is as narrow as a list slot, but never squeezes the title and its tabs")
    func compactWidth() {
        func width(titleWidth: Double, contentWidth: Double, tabCount: Int) -> Double {
            LauncherListPolicy.launcherTabsColumnWidth(
                titleWidth: titleWidth, contentWidth: contentWidth, tabCount: tabCount)
        }
        // 짧은 내용이면 목록 칸 최소 폭이지만, 제목 + 탭 셋은 늘 들어간다.
        let tabs = width(titleWidth: 60, contentWidth: 90, tabCount: 3)
        let minimumHeader: Double = 60 + 3 * 22 + 2 * 2 + 10
        #expect(tabs >= minimumHeader)
        #expect(tabs <= LauncherListPolicy.listColumnWidthRange.upperBound)
        // 탭이 하나면 아이콘 자리가 없다.
        #expect(width(titleWidth: 60, contentWidth: 90, tabCount: 1) == 112)
        // 긴 이름은 목록 칸과 같은 상한에서 자른다.
        #expect(width(titleWidth: 60, contentWidth: 400, tabCount: 3) == 170)
        #expect(LauncherListPolicy.title(for: .url) == "Sites")
        #expect(LauncherListPolicy.title(for: .app) == "Apps")
        #expect(LauncherListPolicy.title(for: .finder) == "Finder")
    }
}
