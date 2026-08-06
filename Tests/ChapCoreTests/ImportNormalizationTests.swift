import Foundation
import Testing

@testable import Chap

// MARK: - Import Normalization Tests

@Suite("Import Normalization")
struct ImportNormalizationTests {

    // MARK: - Size Clamping

    @Test("clamps width below 100 to 100")
    func clampsSmallWidth() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 50, height: 600, launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.sites[0].width == 100)
    }

    @Test("clamps height below 100 to 100")
    func clampsSmallHeight() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 30, launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.sites[0].height == 100)
    }

    @Test("does not change size at or above 100")
    func keepsValidSize() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600, launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.sites[0].width == 800)
        #expect(result.sites[0].height == 600)
    }

    @Test("clamps display override size below 100")
    func clampsDisplayOverrideSize() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displaySizeOverrides: [
                DisplaySizeOverride(
                    displayName: "Built-in Retina Display",
                    width: 50,
                    height: 30)
            ],
            launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.sites[0].displaySizeOverrides[0].width == 100)
        #expect(result.sites[0].displaySizeOverrides[0].height == 100)
    }

    // MARK: - Unknown Preset Removal

    @Test("removes unknown preset and preserves custom width/height")
    func removesUnknownPreset() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 900, height: 500,
            windowSizePreset: "bogus", launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.sites[0].windowSizePreset == nil)
        #expect(result.sites[0].width == 900)
        #expect(result.sites[0].height == 500)
    }

    @Test("keeps known preset untouched")
    func keepsKnownPreset() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            windowSizePreset: "standard", launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.sites[0].windowSizePreset == "standard")
    }

    @Test("removes unknown display override preset")
    func removesUnknownDisplayOverridePreset() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displaySizeOverrides: [
                DisplaySizeOverride(
                    displayName: "Built-in Retina Display",
                    windowSizePreset: "bogus",
                    width: 900,
                    height: 600)
            ],
            launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.sites[0].displaySizeOverrides[0].windowSizePreset == nil)
    }

    // MARK: - Shortcut Sanitization

    @Test("duplicate shortcuts are sanitized during import")
    func sanitizesDuplicateShortcuts() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600, launchType: .url,
                shortcut: "G"),
            Site(
                name: "B", url: "https://b.com", width: 800, height: 600, launchType: .url,
                shortcut: "g"),
        ]
        let result = normalizeForImport(sites: sites, connectedDisplays: [])
        #expect(result.sites[0].shortcut == "G")
        #expect(result.sites[1].shortcut == nil)
    }

    // MARK: - Blocking Issues

    @Test("site with empty name generates blocking issue")
    func emptyNameBlocking() {
        let site = Site(
            name: "", url: "https://example.com", width: 800, height: 600, launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.blockingIssues.contains { $0.siteIndex == 0 && $0.field == .name })
    }

    @Test("url site with bare domain generates blocking issue")
    func bareDomainBlocking() {
        let site = Site(name: "Test", url: "example.com", width: 800, height: 600, launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.blockingIssues.contains { $0.siteIndex == 0 && $0.field == .url })
    }

    @Test("app site with missing appPath generates blocking issue")
    func missingAppPathBlocking() {
        let site = Site(
            name: "Test", url: "", width: 800, height: 600, launchType: .app, appPath: nil)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.blockingIssues.contains { $0.siteIndex == 0 && $0.field == .appPath })
    }

    @Test("valid sites produce no blocking issues")
    func noBlockingOnValid() {
        let site = Site(
            name: "GitHub", url: "https://github.com", width: 800, height: 600, launchType: .url)
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.blockingIssues.isEmpty)
    }

    @Test("duplicate URLs generate a blocking issue")
    func duplicateURLsBlockImport() {
        let sites = [
            Site(name: "A", url: "https://a.com", width: 800, height: 600),
            Site(name: "B", url: "https://a.com", width: 800, height: 600),
        ]
        let result = normalizeForImport(sites: sites, connectedDisplays: [])
        #expect(result.blockingIssues.contains { $0.siteIndex == 1 && $0.field == .url })
    }

    @Test("safe normalization reports automatic fixes")
    func reportsFixes() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 50, height: 600,
            windowSizePreset: "unknown")
        let result = normalizeForImport(sites: [site], connectedDisplays: [])
        #expect(result.fixes.count == 2)
    }

    // MARK: - Display UUID Migration

    @Test("unique display name match augments displayIdentifier")
    func uniqueNameAugmentsUUID() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displayName: "DELL U2720Q", displayIdentifier: nil, launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "Built-in Retina Display"),
            DisplayMatchCandidate(identifier: "UUID-B", name: "DELL U2720Q"),
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == "UUID-B")
    }

    @Test("duplicate display name does NOT pick one, keeps nil identifier")
    func duplicateNameKeepsNil() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displayName: "DELL U2720Q", displayIdentifier: nil, launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "DELL U2720Q"),
            DisplayMatchCandidate(identifier: "UUID-B", name: "DELL U2720Q"),
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == nil)
        #expect(result.sites[0].displayName == "DELL U2720Q")
    }

    @Test("duplicate display name generates ambiguous warning")
    func duplicateNameWarning() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displayName: "DELL U2720Q", displayIdentifier: nil, launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "DELL U2720Q"),
            DisplayMatchCandidate(identifier: "UUID-B", name: "DELL U2720Q"),
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.warnings.contains { $0.siteIndex == 0 && $0.kind == .ambiguousDisplay })
    }

    @Test("disconnected display generates warning")
    func disconnectedDisplayWarning() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displayName: "Unknown Monitor", displayIdentifier: nil, launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "Built-in Retina Display")
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.warnings.contains { $0.siteIndex == 0 && $0.kind == .disconnectedDisplay })
    }

    @Test("site with nil displayName produces no display warning")
    func nilDisplayNoWarning() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600, launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "Built-in Retina Display")
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.warnings.isEmpty)
    }

    @Test("site with connected displayIdentifier keeps it")
    func connectedIdentifierKept() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displayName: "DELL U2720Q", displayIdentifier: "UUID-EXISTING", launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-EXISTING", name: "DELL U2720Q")
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == "UUID-EXISTING")
    }

    @Test("connected displayIdentifier with missing displayName is completed")
    func connectedIdentifierCompletesDisplayName() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displayName: nil, displayIdentifier: "UUID-EXISTING", launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-EXISTING", name: "Studio Display")
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == "UUID-EXISTING")
        #expect(result.sites[0].displayName == "Studio Display")
        #expect(result.fixes.contains { $0.siteIndex == 0 })
    }

    @Test("stale displayIdentifier is updated when name match is unique")
    func staleIdentifierUpdated() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displayName: "DELL U2720Q", displayIdentifier: "UUID-STALE", launchType: .url)
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-CURRENT", name: "DELL U2720Q")
        ]
        let result = normalizeForImport(sites: [site], connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == "UUID-CURRENT")
        #expect(!result.fixes.isEmpty)
    }
}

// MARK: - Display Migration Tests

@Suite("Display Migration")
struct DisplayMigrationTests {

    @Test("migrateDisplayIdentifiers augments UUID for unique name match")
    func augmentsUUIDForUniqueName() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600,
                displayName: "DELL U2720Q", displayIdentifier: nil, launchType: .url),
            Site(
                name: "B", url: "https://b.com", width: 800, height: 600,
                displayName: "Built-in Retina Display", displayIdentifier: nil, launchType: .url),
        ]
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-BUILTIN", name: "Built-in Retina Display"),
            DisplayMatchCandidate(identifier: "UUID-DELL", name: "DELL U2720Q"),
        ]
        let result = migrateDisplayIdentifiers(sites: sites, connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == "UUID-DELL")
        #expect(result.sites[1].displayIdentifier == "UUID-BUILTIN")
    }

    @Test("migrateDisplayIdentifiers skips connected identifiers")
    func skipsConnectedIdentifiers() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600,
                displayName: "DELL U2720Q", displayIdentifier: "UUID-DELL", launchType: .url)
        ]
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-DELL", name: "DELL U2720Q")
        ]
        let result = migrateDisplayIdentifiers(sites: sites, connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == "UUID-DELL")
    }

    @Test("migrateDisplayIdentifiers completes missing name for connected UUID")
    func completesMissingNameForConnectedUUID() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600,
                displayName: nil, displayIdentifier: "UUID-DELL", launchType: .url)
        ]
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-DELL", name: "DELL U2720Q")
        ]
        let result = migrateDisplayIdentifiers(sites: sites, connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == "UUID-DELL")
        #expect(result.sites[0].displayName == "DELL U2720Q")
        #expect(result.warnings.isEmpty)
    }

    @Test("migrateDisplayIdentifiers reports ambiguous names")
    func reportsAmbiguous() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600,
                displayName: "DELL U2720Q", displayIdentifier: nil, launchType: .url)
        ]
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "DELL U2720Q"),
            DisplayMatchCandidate(identifier: "UUID-B", name: "DELL U2720Q"),
        ]
        let result = migrateDisplayIdentifiers(sites: sites, connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == nil)
        #expect(result.warnings.contains { $0.siteIndex == 0 && $0.kind == .ambiguousDisplay })
    }

    @Test("migrateDisplayIdentifiers reports disconnected displays")
    func reportsDisconnected() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600,
                displayName: "LG 27UK850", displayIdentifier: nil, launchType: .url)
        ]
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "Built-in Retina Display")
        ]
        let result = migrateDisplayIdentifiers(sites: sites, connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == nil)
        #expect(result.warnings.contains { $0.siteIndex == 0 && $0.kind == .disconnectedDisplay })
    }

    @Test("migrateDisplayIdentifiers skips sites with nil displayName")
    func skipsNilDisplayName() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600,
                displayName: nil, displayIdentifier: nil, launchType: .url)
        ]
        let displays = [
            DisplayMatchCandidate(identifier: "UUID-A", name: "Built-in Retina Display")
        ]
        let result = migrateDisplayIdentifiers(sites: sites, connectedDisplays: displays)
        #expect(result.sites[0].displayIdentifier == nil)
        #expect(result.warnings.isEmpty)
    }
}
