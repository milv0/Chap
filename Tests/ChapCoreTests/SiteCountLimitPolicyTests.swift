import Testing

@testable import Chap

@Suite("SiteCountLimitPolicy")
struct SiteCountLimitPolicyTests {
    private func site(_ launchType: LaunchType) -> Site {
        Site(
            name: "S", url: launchType == .url ? "https://a.com" : "", width: 800, height: 600,
            launchType: launchType)
    }

    @Test("the limit is four per launch type")
    func limitIsFour() {
        #expect(SiteCountLimitPolicy.maxPerLaunchType == 4)
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
        let sites = Array(repeating: site(.shell), count: 2)
        #expect(SiteCountLimitPolicy.remainingSlots(for: .shell, in: sites) == 2)
        #expect(SiteCountLimitPolicy.remainingSlots(for: .url, in: sites) == 4)
    }
}
