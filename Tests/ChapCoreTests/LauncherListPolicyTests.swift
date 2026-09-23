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
            site("Script", .shell), site("Docs", .finder), site("Mail", .app),
            site("Site", .url),
        ]

        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])

        #expect(sections.map(\.launchType) == [.url, .app, .finder, .shell])
        #expect(
            sections.map { $0.entries.map(\.site.name) } == [
                ["Site"], ["Mail"], ["Docs"], ["Script"],
            ])
    }

    @Test("preserves original indices so launching stays correct")
    func preservesOriginalIndices() {
        let sites = [site("Script", .shell), site("Site", .url), site("Mail", .app)]

        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])

        let flattened = sections.flatMap(\.entries)
        #expect(flattened.map(\.siteIndex) == [1, 2, 0])
        #expect(flattened.map(\.site.name) == ["Site", "Mail", "Script"])
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
        let sites = [site("Site", .url), site("Script", .shell), site("Docs", .finder)]

        let sections = LauncherListPolicy.sections(
            sites: sites, hiddenLaunchTypes: [.shell, .finder])

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
        #expect(LauncherListPolicy.symbolName(for: .shell) == "terminal.fill")
    }
}
