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

    @Test("one Launchers slot holds the Sites and Finder lists, not the Apps grid")
    func slotHoldsListTypes() {
        let sites = [site("Finder", .finder), site("Slack", .app), site("Docs", .url)]

        let slots = NotchSlotContent.slots(widgets: [.none, .none, .launchers], sites: sites)

        #expect(slots.count == 1)
        guard case .launcherTabs(let sections) = slots.first else {
            Issue.record("expected a Launchers slot")
            return
        }
        #expect(sections.map(\.launchType) == [.url, .finder])
    }

    @Test("with no Sites or Finder items, the slot is left out, even when apps exist")
    func emptyLaunchersIsSkipped() {
        #expect(NotchSlotContent.slots(widgets: [.none, .none, .launchers], sites: []).isEmpty)
        #expect(
            NotchSlotContent.slots(
                widgets: [.none, .none, .launchers], sites: [site("Slack", .app)]
            ).isEmpty)
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

    @Test("Launchers and Apps sit side by side in the free slots")
    func launchersBesideApps() {
        let layout: [NotchWidget] = [.screenshots, .downloads, .launchers, .apps, .awake, .todo]
        #expect(NotchWidget.normalizedSlots(layout) == layout)
        #expect(LauncherListPolicy.launcherTabTypes == [.url, .finder])
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
        // 고른 탭(아이콘 + 이름)과 나머지 두 아이콘이 늘 들어간다.
        let tabs = width(titleWidth: 80, contentWidth: 90, tabCount: 3)
        let minimumHeader: Double = 80 + 2 * (22 + 2)
        #expect(tabs >= minimumHeader)
        #expect(tabs <= LauncherListPolicy.listColumnWidthRange.upperBound)
        // 짧은 제목과 본문이면 목록 칸 최소 폭이다.
        #expect(width(titleWidth: 60, contentWidth: 90, tabCount: 2) == 112)
        // 탭이 하나면 아이콘 자리가 없다.
        #expect(width(titleWidth: 60, contentWidth: 90, tabCount: 1) == 112)
        // 긴 이름은 목록 칸과 같은 상한에서 자른다.
        #expect(width(titleWidth: 60, contentWidth: 400, tabCount: 3) == 170)
        #expect(LauncherListPolicy.title(for: .url) == "Sites")
        #expect(LauncherListPolicy.title(for: .app) == "Apps")
        #expect(LauncherListPolicy.title(for: .finder) == "Finder")
    }
}

@Suite("Apps slot with Layouts")
struct AppsSlotTests {
    private func app(_ name: String) -> Site {
        Site(
            name: name, url: "", width: 800, height: 600, launchType: .app,
            appPath: "/Applications/\(name).app")
    }

    @Test("the Apps slot carries the apps and the layouts together")
    func slotCarriesBoth() {
        let slots = NotchSlotContent.slots(
            widgets: [.none, .none, .apps], sites: [app("Slack")],
            layouts: [ChapLayout(name: "Deep Work", windows: [])])
        guard case .apps(let apps, let layouts) = slots.first else {
            Issue.record("expected an Apps slot")
            return
        }
        #expect(apps?.entries.map(\.site.name) == ["Slack"])
        #expect(layouts.map(\.name) == ["Deep Work"])
    }

    @Test("Layouts is always a tab; Apps only when there are apps")
    func availableTabs() {
        #expect(AppsSlotTab.available(hasApps: true) == [.apps, .layouts])
        #expect(AppsSlotTab.available(hasApps: false) == [.layouts])
    }

    @Test("the tab remembers the last one, falling back to the first available")
    func selectedTab() {
        #expect(AppsSlotTab.selected(stored: "layouts", hasApps: true) == .layouts)
        #expect(AppsSlotTab.selected(stored: "apps", hasApps: false) == .layouts)
        #expect(AppsSlotTab.selected(stored: nil, hasApps: true) == .apps)
        #expect(AppsSlotTab.selected(stored: "nope", hasApps: true) == .apps)
        // 2.17까지 저장한 "workspaces"는 Layouts 탭으로 읽는다.
        #expect(AppsSlotTab.selected(stored: "workspaces", hasApps: true) == .layouts)
    }

    @Test("with Launchers and Apps, every widget fits in the six slots")
    func everyWidgetFits() {
        let all: [NotchWidget] = [.screenshots, .downloads, .launchers, .apps, .awake, .todo]
        #expect(NotchWidget.normalizedSlots(all) == all)
        // 칸에 놓을 수 있는 위젯이 모두 들어간다(빈 칸·Drop 제외).
        let placeable = Set(NotchWidget.allCases).subtracting([.none, .drop])
        #expect(Set(all) == placeable)
    }
}

@Suite("Merged slot migration")
struct MergedSlotMigrationTests {
    private func widgets(_ raw: String) throws -> [NotchWidget] {
        let json = #"{"notchWidgets": \#(raw), "sites": []}"#
        return try JSONDecoder().decode(Config.self, from: Data(json.utf8)).notchWidgets
    }

    @Test("Sites and Finder slots become one Launchers slot; the second is left empty")
    func listSlotsBecomeLaunchers() throws {
        #expect(
            try widgets(#"["screenshots", "none", "sites", "apps", "folders", "none"]"#)
                == [.screenshots, .none, .launchers, .apps, .none, .none])
        #expect(
            try widgets(#"["screenshots", "none", "folders", "todo", "awake", "none"]"#)
                == [.screenshots, .none, .launchers, .todo, .awake, .none])
    }

    @Test("with Launchers already placed, old Sites and Finder slots are left empty")
    func listSlotsBesideLaunchers() throws {
        #expect(
            try widgets(#"["screenshots", "none", "sites", "launchers", "folders", "none"]"#)
                == [.screenshots, .none, .none, .launchers, .none, .none])
    }

    @Test("a Layouts slot becomes the Apps slot, or empty when Apps is already placed")
    func layoutsBecomesApps() throws {
        #expect(
            try widgets(#"["screenshots", "none", "workspaces", "todo", "none", "none"]"#)
                == [.screenshots, .none, .apps, .todo, .none, .none])
        #expect(
            try widgets(#"["screenshots", "none", "apps", "workspaces", "todo", "none"]"#)
                == [.screenshots, .none, .apps, .none, .todo, .none])
    }

    @Test("Sites, Finder, and Layouts are no longer slots of their own")
    func formerSlotsAreGone() {
        #expect(NotchWidget(rawValue: "sites") == nil)
        #expect(NotchWidget(rawValue: "folders") == nil)
        #expect(NotchWidget(rawValue: NotchWidget.formerWorkspacesRawValue) == nil)
    }
}
