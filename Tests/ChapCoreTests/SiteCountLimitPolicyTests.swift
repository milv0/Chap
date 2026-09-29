import Testing

@testable import Chap

@Suite("SiteCountLimitPolicy")
struct SiteCountLimitPolicyTests {
    private func site(_ launchType: LaunchType) -> Site {
        Site(
            name: "S", url: launchType == .url ? "https://a.com" : "", width: 800, height: 600,
            launchType: launchType)
    }

    @Test("URL and Finder allow four, App allows six")
    func limitsPerType() {
        #expect(SiteCountLimitPolicy.limit(for: .url) == 4)
        #expect(SiteCountLimitPolicy.limit(for: .finder) == 4)
        #expect(SiteCountLimitPolicy.limit(for: .app) == 6)
    }

    @Test("apps can be added up to six")
    func appsUpToSix() {
        #expect(SiteCountLimitPolicy.canAdd(.app, to: Array(repeating: site(.app), count: 5)))
        #expect(!SiteCountLimitPolicy.canAdd(.app, to: Array(repeating: site(.app), count: 6)))
        #expect(
            SiteCountLimitPolicy.remainingSlots(
                for: .app, in: Array(repeating: site(.app), count: 4))
                == 2)
    }

    @Test("adding is allowed below the limit")
    func canAddBelowLimit() {
        let sites = Array(repeating: site(.url), count: 3)
        #expect(SiteCountLimitPolicy.canAdd(.url, to: sites))
    }

    @Test("adding is blocked once the type reaches the limit")
    func cannotAddAtLimit() {
        let sites = Array(repeating: site(.url), count: 4)
        #expect(SiteCountLimitPolicy.canAdd(.url, to: sites) == false)
    }

    @Test("the limit is independent per launch type")
    func limitIsPerType() {
        let sites = Array(repeating: site(.url), count: 4) + [site(.app)]
        #expect(SiteCountLimitPolicy.canAdd(.url, to: sites) == false)
        #expect(SiteCountLimitPolicy.canAdd(.app, to: sites))
        #expect(SiteCountLimitPolicy.canAdd(.finder, to: sites))
    }

    @Test("remaining slots reports how many more can be added")
    func remainingSlots() {
        let sites = Array(repeating: site(.finder), count: 2)
        #expect(SiteCountLimitPolicy.remainingSlots(for: .finder, in: sites) == 2)
        #expect(SiteCountLimitPolicy.remainingSlots(for: .url, in: sites) == 4)
    }
}
