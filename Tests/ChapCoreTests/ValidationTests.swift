import Foundation
import Testing

@testable import Chap

@Suite("Domain Validation")
struct DomainValidationTests {
    @Test(arguments: [
        ("google.com", true),
        ("sub.domain.co.uk", true),
        ("valid-host_name.123", true),
        ("a", true),
        ("evil<script>", false),
        ("has space", false),
        ("", false),
        ("with/slash", false),
        ("quote\"mark", false),
    ])
    func domainValidation(domain: String, shouldPass: Bool) {
        #expect(isValidDomain(domain) == shouldPass)
    }
}

@Suite("Launch URL Validation")
struct LaunchURLValidationTests {
    @Test(arguments: [
        ("https://example.com", true),
        (" http://sub.domain.co.uk/path?q=1 ", true),
        ("ftp://example.com", false),
        ("example.com", false),
        ("https://", false),
        ("https://bad host.com", false),
        ("https://evil<script>.com", false),
    ])
    func launchURLValidation(url: String, shouldPass: Bool) {
        #expect(isValidLaunchURL(url) == shouldPass)
    }

    @Test("returns host for valid launch URL")
    func returnsHost() {
        #expect(launchURLHost("https://www.example.com/path") == "www.example.com")
    }
}

@Suite("Display Matching")
struct DisplayMatchingTests {
    private let builtIn = DisplayMatchCandidate(
        identifier: "UUID-A", name: "Built-in Retina Display")
    private let ext1 = DisplayMatchCandidate(identifier: "UUID-B", name: "DELL U2720Q")
    private let ext2 = DisplayMatchCandidate(identifier: "UUID-C", name: "DELL U2720Q")

    @Test("UUID match wins over name and disambiguates identical models")
    func uuidWins() {
        let displays = [builtIn, ext1, ext2]
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: "UUID-C", displayName: "DELL U2720Q", among: displays) == 2)
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: "UUID-B", displayName: "DELL U2720Q", among: displays) == 1)
    }

    @Test("falls back to name when identifier is nil (legacy config)")
    func nameFallback() {
        let displays = [builtIn, ext1]
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: nil, displayName: "DELL U2720Q", among: displays) == 1)
    }

    @Test("falls back to name when the saved UUID is not connected")
    func uuidMissingFallsBackToName() {
        let displays = [builtIn, ext1]
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: "UUID-GONE", displayName: "DELL U2720Q", among: displays) == 1)
    }

    @Test("returns nil when nothing matches (cursor-screen fallback)")
    func noMatch() {
        let displays = [builtIn]
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: "UUID-X", displayName: "Unknown", among: displays) == nil)
        #expect(
            resolvedDisplayIndex(displayIdentifier: nil, displayName: nil, among: displays) == nil)
    }

    @Test("does not choose an ambiguous display name without a UUID")
    func ambiguousNameDoesNotResolve() {
        let displays = [builtIn, ext1, ext2]
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: nil, displayName: "DELL U2720Q", among: displays) == nil)
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: "UUID-GONE", displayName: "DELL U2720Q", among: displays)
                == nil)
    }

    @Test("empty identifier/name are ignored")
    func emptyIgnored() {
        let displays = [builtIn, ext1]
        #expect(
            resolvedDisplayIndex(
                displayIdentifier: "", displayName: "DELL U2720Q", among: displays) == 1)
        #expect(
            resolvedDisplayIndex(displayIdentifier: nil, displayName: "", among: displays) == nil)
    }

    @Test("Site round-trips displayIdentifier")
    func siteRoundTrip() throws {
        let original = Site(
            name: "Work", url: "https://work.com", width: 800, height: 600,
            displayName: "DELL U2720Q", displayIdentifier: "UUID-C")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Site.self, from: data)
        #expect(decoded.displayIdentifier == "UUID-C")
        #expect(decoded == original)
    }

    @Test("display size override matches current screen by UUID")
    func displaySizeOverrideMatchesUUID() {
        let overrides = [
            DisplaySizeOverride(
                displayName: "Built-in Retina Display",
                displayIdentifier: "UUID-A",
                windowSizePreset: "max",
                width: 1000,
                height: 700),
            DisplaySizeOverride(
                displayName: "DELL U2720Q",
                displayIdentifier: "UUID-B",
                windowSizePreset: "standard",
                width: 1200,
                height: 750),
        ]

        #expect(
            displaySizeOverrideIndex(
                displayIdentifier: "UUID-B",
                displayName: "DELL U2720Q",
                among: overrides) == 1)
    }

    @Test("display size override falls back to unique display name")
    func displaySizeOverrideFallsBackToName() {
        let overrides = [
            DisplaySizeOverride(
                displayName: "Built-in Retina Display",
                displayIdentifier: nil,
                width: 1000,
                height: 700),
            DisplaySizeOverride(
                displayName: "DELL U2720Q",
                displayIdentifier: nil,
                width: 1200,
                height: 750),
        ]

        #expect(
            displaySizeOverrideIndex(
                displayIdentifier: nil,
                displayName: "DELL U2720Q",
                among: overrides) == 1)
    }

    @Test("ambiguous display size override names do not match")
    func ambiguousDisplaySizeOverrideDoesNotMatch() {
        let overrides = [
            DisplaySizeOverride(displayName: "DELL U2720Q", width: 1200, height: 750),
            DisplaySizeOverride(displayName: "DELL U2720Q", width: 1300, height: 800),
        ]

        #expect(
            displaySizeOverrideIndex(
                displayIdentifier: nil,
                displayName: "DELL U2720Q",
                among: overrides) == nil)
    }
}

@Suite("Display Selection")
struct DisplaySelectionTests {
    @Test("nil display fields mean Follow Cursor")
    func nilDisplayFieldsMeanFollowCursor() {
        let site = Site(name: "A", url: "https://a.com", width: 800, height: 600)

        #expect(!hasExplicitDisplaySelection(site))
    }

    @Test("displayIdentifier alone is explicit")
    func displayIdentifierAloneIsExplicit() {
        let site = Site(
            name: "A", url: "https://a.com", width: 800, height: 600,
            displayIdentifier: "UUID-A")

        #expect(hasExplicitDisplaySelection(site))
    }

    @Test("blank display fields mean Follow Cursor")
    func blankDisplayFieldsMeanFollowCursor() {
        let site = Site(
            name: "A", url: "https://a.com", width: 800, height: 600,
            displayName: " ", displayIdentifier: "")

        #expect(!hasExplicitDisplaySelection(site))
    }
}

@Suite("Shortcut Sanitization")
struct ShortcutSanitizationTests {
    private func site(_ name: String, _ shortcut: String?) -> Site {
        Site(name: name, url: "https://\(name).com", width: 800, height: 600, shortcut: shortcut)
    }

    @Test("keeps distinct valid shortcuts unchanged")
    func keepsDistinctShortcuts() {
        let result = sanitizedShortcuts(for: [site("a", "G"), site("b", "T"), site("c", nil)])
        #expect(result.map(\.shortcut) == ["G", "T", nil])
    }

    @Test("clears duplicates case-insensitively, keeping the first")
    func clearsDuplicates() {
        let result = sanitizedShortcuts(for: [site("a", "G"), site("b", "g"), site("c", "G")])
        #expect(result.map(\.shortcut) == ["G", nil, nil])
    }

    @Test("clears reserved keys . and ,")
    func clearsReservedKeys() {
        let result = sanitizedShortcuts(for: [site("a", "."), site("b", ","), site("c", "K")])
        #expect(result.map(\.shortcut) == [nil, nil, "K"])
    }

    @Test("normalizes empty or whitespace-only shortcuts to nil")
    func normalizesEmpty() {
        let result = sanitizedShortcuts(for: [site("a", ""), site("b", "   "), site("c", "M")])
        #expect(result.map(\.shortcut) == [nil, nil, "M"])
    }

    @Test("clears shortcuts containing more than one character")
    func clearsMultipleCharacters() {
        let result = sanitizedShortcuts(for: [site("a", "AB"), site("b", "K")])
        #expect(result.map(\.shortcut) == [nil, "K"])
    }

    @Test("trims surrounding whitespace but preserves the key")
    func trimsWhitespace() {
        let result = sanitizedShortcuts(for: [site("a", " P ")])
        #expect(result.map(\.shortcut) == ["P"])
    }

    @Test("a reserved-key duplicate does not consume the dedupe slot")
    func reservedDoesNotReserveSlot() {
        let result = sanitizedShortcuts(for: [site("a", ","), site("b", "Z"), site("c", "z")])
        #expect(result.map(\.shortcut) == [nil, "Z", nil])
    }
}
