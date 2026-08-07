import Foundation
import Testing

@testable import Chap

// MARK: - Config Validation Tests

@Suite("Config Validation")
struct ConfigValidationTests {

    // MARK: - Required Fields

    @Test("site with empty name is invalid")
    func emptyNameInvalid() {
        let site = Site(
            name: "", url: "https://example.com", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .name })
    }

    @Test("site with placeholder name is invalid")
    func placeholderNameInvalid() {
        let site = Site(
            name: Defaults.newSiteName, url: "https://example.com", width: 800, height: 600,
            launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .name })
    }

    @Test("url launch type requires non-empty url")
    func urlLaunchTypeRequiresURL() {
        let site = Site(name: "Test", url: "", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .url })
    }

    @Test("app launch type requires non-empty appPath")
    func appLaunchTypeRequiresAppPath() {
        let site = Site(
            name: "Test", url: "", width: 800, height: 600, launchType: .app, appPath: nil)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .appPath })
    }

    @Test("finder launch type requires non-empty folderPath")
    func finderLaunchTypeRequiresFolderPath() {
        let site = Site(
            name: "Test", url: "", width: 800, height: 600, launchType: .finder, folderPath: nil)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .folderPath })
    }

    @Test("shell launch type requires non-empty script")
    func shellLaunchTypeRequiresScript() {
        let site = Site(
            name: "Test", url: "", width: 800, height: 600, launchType: .shell, script: nil)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .script })
    }

    // MARK: - URL Scheme Validation

    @Test("url must start with http:// or https://")
    func urlMustHaveScheme() {
        let site = Site(name: "Test", url: "example.com", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .url })
    }

    @Test("url with http:// is valid")
    func httpURLValid() {
        let site = Site(
            name: "Test", url: "http://example.com", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(!result.issues.contains { $0.field == .url })
    }

    @Test("url with https:// is valid")
    func httpsURLValid() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(!result.issues.contains { $0.field == .url })
    }

    @Test("url with ftp:// scheme is invalid")
    func ftpURLInvalid() {
        let site = Site(
            name: "Test", url: "ftp://files.example.com", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .url })
    }

    @Test("url must include a host")
    func urlRequiresHost() {
        let site = Site(name: "Test", url: "https://", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .url })
    }

    @Test("url host must pass launch URL validation")
    func urlHostMustPassLaunchValidation() {
        let site = Site(
            name: "Test", url: "https://bad host.com", width: 800, height: 600,
            launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .url })
    }

    // MARK: - Duplicate Detection

    @Test("duplicate shortcuts are detected")
    func duplicateShortcuts() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600, launchType: .url,
                shortcut: "G"),
            Site(
                name: "B", url: "https://b.com", width: 800, height: 600, launchType: .url,
                shortcut: "g"),
        ]
        let result = validateConfig(Config(sites: sites))
        #expect(result.issues.contains { $0.field == .shortcut && $0.severity == .error })
    }

    @Test("reserved shortcut keys are rejected")
    func reservedShortcut() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600, launchType: .url,
                shortcut: "."),
            Site(
                name: "B", url: "https://b.com", width: 800, height: 600, launchType: .url,
                shortcut: ","),
        ]
        let result = validateConfig(Config(sites: sites))
        #expect(result.errors.filter { $0.field == .shortcut }.count == 2)
    }

    @Test("a reserved shortcut does not mask a real duplicate")
    func reservedShortcutDoesNotMaskDuplicate() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600, launchType: .url,
                shortcut: "."),
            Site(
                name: "B", url: "https://b.com", width: 800, height: 600, launchType: .url,
                shortcut: "G"),
            Site(
                name: "C", url: "https://c.com", width: 800, height: 600, launchType: .url,
                shortcut: "g"),
        ]
        let result = validateConfig(Config(sites: sites))

        #expect(result.errors.filter { $0.field == .shortcut }.count == 2)
        #expect(result.errors.contains { $0.field == .shortcut && $0.siteIndex == 2 })
    }

    @Test("shortcut must contain exactly one character")
    func shortcutMustContainOneCharacter() {
        let site = Site(
            name: "A", url: "https://a.com", width: 800, height: 600, launchType: .url,
            shortcut: "AB")

        let result = validateConfig(Config(sites: [site]))

        #expect(result.errors.contains { $0.field == .shortcut })
    }

    @Test("duplicate URLs across url-type sites are warned")
    func duplicateURLs() {
        let sites = [
            Site(name: "A", url: "https://example.com", width: 800, height: 600, launchType: .url),
            Site(name: "B", url: "https://example.com", width: 800, height: 600, launchType: .url),
        ]
        let result = validateConfig(Config(sites: sites))
        #expect(result.issues.contains { $0.field == .url && $0.severity == .error })
    }

    @Test("duplicate appPaths across app-type sites are warned")
    func duplicateAppPaths() {
        let sites = [
            Site(
                name: "A", url: "", width: 800, height: 600, launchType: .app,
                appPath: "/Applications/Slack.app"),
            Site(
                name: "B", url: "", width: 800, height: 600, launchType: .app,
                appPath: "/Applications/Slack.app"),
        ]
        let result = validateConfig(Config(sites: sites))
        #expect(result.issues.contains { $0.field == .appPath && $0.severity == .error })
    }

    @Test("duplicate folderPaths across finder-type sites are warned")
    func duplicateFolderPaths() {
        let sites = [
            Site(
                name: "A", url: "", width: 800, height: 600, launchType: .finder,
                folderPath: "~/Downloads"),
            Site(
                name: "B", url: "", width: 800, height: 600, launchType: .finder,
                folderPath: "~/Downloads"),
        ]
        let result = validateConfig(Config(sites: sites))
        #expect(result.issues.contains { $0.field == .folderPath && $0.severity == .error })
    }

    // MARK: - Unknown Preset

    @Test("unknown windowSizePreset is detected")
    func unknownPreset() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            windowSizePreset: "nonexistent", launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .windowSizePreset })
    }

    @Test("known windowSizePreset passes validation")
    func knownPreset() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            windowSizePreset: "standard", launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(!result.issues.contains { $0.field == .windowSizePreset })
    }

    @Test("unknown display override preset is detected")
    func unknownDisplayOverridePreset() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displaySizeOverrides: [
                DisplaySizeOverride(
                    displayName: "Built-in Retina Display",
                    windowSizePreset: "nonexistent",
                    width: 900,
                    height: 600)
            ],
            launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .windowSizePreset })
    }

    // MARK: - Size Validation

    @Test("width below 100 is invalid")
    func widthBelowMinimum() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 50, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .width })
    }

    @Test("height below 100 is invalid")
    func heightBelowMinimum() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 50, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .height })
    }

    @Test("display override size below 100 is invalid")
    func displayOverrideSizeBelowMinimum() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 800, height: 600,
            displaySizeOverrides: [
                DisplaySizeOverride(
                    displayName: "Built-in Retina Display",
                    width: 90,
                    height: 80)
            ],
            launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .width })
        #expect(result.issues.contains { $0.siteIndex == 0 && $0.field == .height })
    }

    @Test("width and height at 100 are valid")
    func minimumSizeValid() {
        let site = Site(
            name: "Test", url: "https://example.com", width: 100, height: 100, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(!result.issues.contains { $0.field == .width || $0.field == .height })
    }

    // MARK: - Valid Config

    @Test("fully valid config produces no issues")
    func validConfigNoIssues() {
        let sites = [
            Site(
                name: "GitHub", url: "https://github.com", width: 800, height: 600,
                windowSizePreset: "standard", launchType: .url, shortcut: "G"),
            Site(
                name: "Slack", url: "", width: 800, height: 600,
                launchType: .app, appPath: "/Applications/Slack.app", shortcut: "S"),
        ]
        let result = validateConfig(Config(sites: sites))
        #expect(result.issues.isEmpty)
        #expect(result.isValid)
    }

    // MARK: - Result Structure

    @Test("issues carry human-readable messages")
    func issuesHaveMessages() {
        let site = Site(name: "", url: "", width: 50, height: 50, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        for issue in result.issues {
            #expect(!issue.message.isEmpty)
        }
    }

    @Test("isValid is false when errors exist")
    func isValidFalseOnErrors() {
        let site = Site(name: "", url: "", width: 800, height: 600, launchType: .url)
        let result = validateConfig(Config(sites: [site]))
        #expect(!result.isValid)
    }

    @Test("isValid is false when duplicate values exist")
    func isValidFalseOnDuplicates() {
        let sites = [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600, launchType: .url,
                shortcut: "G"),
            Site(
                name: "B", url: "https://b.com", width: 800, height: 600, launchType: .url,
                shortcut: "g"),
        ]
        let result = validateConfig(Config(sites: sites))
        #expect(!result.isValid)
    }

    // MARK: - Export Validation

    @Test("invalid config is blocked from export")
    func invalidConfigIsBlockedFromExport() {
        let config = Config(sites: [
            Site(name: "", url: "https://example.com", width: 800, height: 600)
        ])

        #expect(!validateConfigForExport(config).isValid)
    }

    @Test("valid config is allowed for export")
    func validConfigIsAllowedForExport() {
        let config = Config(sites: [
            Site(name: "Example", url: "https://example.com", width: 800, height: 600)
        ])

        #expect(validateConfigForExport(config).isValid)
    }
}
