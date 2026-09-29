import Testing

@testable import Chap

@Suite("LauncherListPolicy")
struct LauncherListPolicyTests {
    private func site(
        _ name: String, _ launchType: LaunchType, shortcut: String? = nil
    ) -> Site {
        Site(
            name: name, url: launchType == .url ? "https://a.com" : "", width: 800,
            height: 600, launchType: launchType, shortcut: shortcut)
    }

    @Test("groups sites into launch type order regardless of stored order")
    func groupsIntoLaunchTypeOrder() {
        let sites = [
            site("Docs", .finder), site("Mail", .app), site("Site", .url),
        ]

        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])

        #expect(sections.map(\.launchType) == [.url, .app, .finder])
        #expect(
            sections.map { $0.entries.map(\.site.name) } == [
                ["Site"], ["Mail"], ["Docs"],
            ])
    }

    @Test("preserves original indices so launching stays correct")
    func preservesOriginalIndices() {
        let sites = [site("Docs", .finder), site("Site", .url), site("Mail", .app)]

        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])

        let flattened = sections.flatMap(\.entries)
        #expect(flattened.map(\.siteIndex) == [1, 2, 0])
        #expect(flattened.map(\.site.name) == ["Site", "Mail", "Docs"])
    }

    @Test("keeps stored order within one launch type")
    func keepsStoredOrderWithinType() {
        let sites = [site("B", .url), site("A", .url), site("C", .url)]

        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.site.name) == ["B", "A", "C"])
        #expect(sections[0].entries.map(\.siteIndex) == [0, 1, 2])
    }

    @Test("hidden launch types are excluded entirely")
    func hiddenTypesExcluded() {
        let sites = [site("Site", .url), site("Mail", .app), site("Docs", .finder)]

        let sections = LauncherListPolicy.sections(
            sites: sites, hiddenLaunchTypes: [.app, .finder])

        #expect(sections.map(\.launchType) == [.url])
        #expect(sections.flatMap(\.entries).map(\.siteIndex) == [0])
    }

    @Test("empty and fully hidden inputs produce no sections")
    func emptyProducesNoSections() {
        #expect(LauncherListPolicy.sections(sites: [], hiddenLaunchTypes: []).isEmpty)

        let hiddenAll = LauncherListPolicy.sections(
            sites: [site("Site", .url)], hiddenLaunchTypes: [.url])
        #expect(hiddenAll.isEmpty)
    }

    @Test("each launch type maps to its own stable symbol")
    func symbolPerLaunchType() {
        #expect(LauncherListPolicy.symbolName(for: .url) == "bolt.fill")
        #expect(LauncherListPolicy.symbolName(for: .app) == "app.fill")
        #expect(LauncherListPolicy.symbolName(for: .finder) == "folder.fill")
    }

    @Test("notch slot entries are capped at four regardless of section size")
    func notchSlotCapIsFour() {
        let sites = (1...6).map {
            site("S\($0)", .url)
        }

        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])
        let capped = sections[0].entries.prefix(
            LauncherListPolicy.maxEntriesPerNotchSlot(for: sections[0].launchType))

        #expect(LauncherListPolicy.maxEntriesPerNotchSlot(for: .url) == 4)
        #expect(capped.count == 4)
    }
}

@Suite("Notch app icons")
struct NotchAppIconLabelTests {
    private func app(_ name: String, shortcut: String?) -> Site {
        Site(
            name: name, url: "", width: 800, height: 600, launchType: .app,
            appPath: "/Applications/\(name).app", shortcut: shortcut)
    }

    @Test("up to six apps fit in a two-column icon grid of three rows")
    func gridFitsSixApps() {
        #expect(LauncherListPolicy.appIconColumns == 2)
        #expect(LauncherListPolicy.maxEntriesPerNotchSlot(for: .app) == 6)
        #expect(LauncherListPolicy.appIconRows(forCount: 6) == 3)
    }

    @Test(
        "the grid uses only the rows it needs",
        arguments: [(0, 0), (1, 1), (2, 1), (3, 2), (4, 2), (5, 3), (6, 3), (9, 3)])
    func rowsForCount(count: Int, rows: Int) {
        #expect(LauncherListPolicy.appIconRows(forCount: count) == rows)
    }

    @Test("the shortcut badge shows the uppercased Option key")
    func shortcutBadge() {
        #expect(LauncherListPolicy.shortcutBadge(for: app("Slack", shortcut: "s")) == "⌥S")
        #expect(LauncherListPolicy.shortcutBadge(for: app("Mail", shortcut: nil)) == nil)
        #expect(LauncherListPolicy.shortcutBadge(for: app("Notes", shortcut: " ")) == nil)
    }

    @Test("app icon badges show only the key; the header shows Option once")
    func letterOnlyBadge() {
        let slack = app("Slack", shortcut: "s")
        let mail = app("Mail", shortcut: nil)
        #expect(LauncherListPolicy.shortcutKey(for: slack) == "S")
        #expect(LauncherListPolicy.shortcutKey(for: mail) == nil)
        let withShortcut = LauncherListSection(
            launchType: .app,
            entries: [
                LauncherListEntry(siteIndex: 0, site: mail),
                LauncherListEntry(siteIndex: 1, site: slack),
            ])
        let without = LauncherListSection(
            launchType: .app, entries: [LauncherListEntry(siteIndex: 0, site: mail)])
        #expect(LauncherListPolicy.hasShortcut(in: withShortcut))
        #expect(!LauncherListPolicy.hasShortcut(in: without))
    }

    @Test("VoiceOver hears the app name and its shortcut")
    func accessibilityLabel() {
        #expect(
            LauncherListPolicy.launchAccessibilityLabel(for: app("Slack", shortcut: "s"))
                == "Launch Slack, Option S")
        #expect(
            LauncherListPolicy.launchAccessibilityLabel(for: app("Mail", shortcut: nil))
                == "Launch Mail")
    }
}
