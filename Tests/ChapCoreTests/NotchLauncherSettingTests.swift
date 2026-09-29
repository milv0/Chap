import Foundation
import Testing

@testable import Chap

@Suite("Notch Launcher Setting")
struct NotchLauncherSettingTests {
    private func decodeConfig(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    @Test("defaults to off when the key is missing")
    func defaultsToOffWhenMissing() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchLauncherEnabled == false)
    }

    @Test("decodes an explicit enabled value")
    func decodesExplicitValue() throws {
        let config = try decodeConfig(#"{"notchLauncherEnabled": true, "sites": []}"#)

        #expect(config.notchLauncherEnabled)
    }

    @Test("a wrong value type falls back to off instead of failing")
    func wrongTypeFallsBackToOff() throws {
        let config = try decodeConfig(#"{"notchLauncherEnabled": "yes", "sites": []}"#)

        #expect(config.notchLauncherEnabled == false)
    }

    @Test("round-trips through encoding")
    func roundTripsThroughEncoding() throws {
        let original = Config(notchLauncherEnabled: true, sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchLauncherEnabled)
    }

    @Test("style defaults to Custom when the key is missing")
    func styleDefaultsToCustom() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchPanelStyle == .custom)
    }

    @Test("legacy Black and Iceberg styles migrate to Custom")
    func legacyStylesMigrateToCustom() throws {
        let black = try decodeConfig(
            #"{"notchPanelStyle": "black", "sites": []}"#)
        let iceberg = try decodeConfig(
            #"{"notchPanelStyle": "iceberg", "sites": []}"#)

        #expect(black.notchPanelStyle == .custom)
        #expect(iceberg.notchPanelStyle == .custom)
    }

    @Test("decodes the Glass style")
    func decodesGlassStyle() throws {
        let config = try decodeConfig(#"{"notchPanelStyle": "glass", "sites": []}"#)

        #expect(config.notchPanelStyle == .glass)
    }

    @Test("an unknown style string falls back to Custom instead of failing")
    func unknownStyleFallsBackToCustom() throws {
        let config = try decodeConfig(#"{"notchPanelStyle": "lava", "sites": []}"#)

        #expect(config.notchPanelStyle == .custom)
    }

    @Test("Custom style round-trips through encoding")
    func customStyleRoundTripsThroughEncoding() throws {
        let original = Config(notchPanelStyle: .custom, sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchPanelStyle == .custom)
    }

    @Test("glass appearance defaults to system when the key is missing")
    func glassAppearanceDefaultsToSystem() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchGlassAppearance == .system)
    }

    @Test("decodes explicit light and dark Glass appearances")
    func decodesGlassAppearances() throws {
        let light = try decodeConfig(
            #"{"notchGlassAppearance": "light", "sites": []}"#)
        let dark = try decodeConfig(
            #"{"notchGlassAppearance": "dark", "sites": []}"#)

        #expect(light.notchGlassAppearance == .light)
        #expect(dark.notchGlassAppearance == .dark)
    }

    @Test("unknown Glass appearance falls back to system")
    func unknownGlassAppearanceFallsBack() throws {
        let config = try decodeConfig(
            #"{"notchGlassAppearance": "neon", "sites": []}"#)

        #expect(config.notchGlassAppearance == .system)
    }

    @Test("Glass appearance round-trips through encoding")
    func glassAppearanceRoundTrips() throws {
        let original = Config(notchGlassAppearance: .dark, sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchGlassAppearance == .dark)
    }

    @Test(
        "Glass material is independent of appearance",
        arguments: NotchGlassAppearance.allCases)
    func materialIndependentOfAppearance(appearance: NotchGlassAppearance) throws {
        for material in NotchGlassMaterial.allCases {
            let original = Config(
                notchGlassAppearance: appearance, notchGlassMaterial: material, sites: [])
            let decoded = try JSONDecoder().decode(
                Config.self, from: try JSONEncoder().encode(original))
            #expect(decoded.notchGlassAppearance == appearance)
            #expect(decoded.notchGlassMaterial == material)
        }
    }

    @Test("Glass material defaults to the more legible Regular when the key is missing")
    func glassMaterialDefaultsToRegular() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchGlassMaterial == .regular)
    }

    @Test("a saved Clear Glass choice is kept")
    func decodesClearGlassMaterial() throws {
        let config = try decodeConfig(
            #"{"notchGlassMaterial": "clear", "sites": []}"#)

        #expect(config.notchGlassMaterial == .clear)
    }

    @Test("unknown Glass material falls back to Regular")
    func unknownGlassMaterialFallsBack() throws {
        let config = try decodeConfig(
            #"{"notchGlassMaterial": "heavy", "sites": []}"#)

        #expect(config.notchGlassMaterial == .regular)
    }

    @Test("Glass material round-trips through encoding")
    func glassMaterialRoundTrips() throws {
        let original = Config(notchGlassMaterial: .regular, sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchGlassMaterial == .regular)
    }

    @Test("opacity defaults to 0.6 when the key is missing")
    func opacityDefaultsWhenMissing() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchPanelOpacity == 0.6)
    }

    @Test("decodes an explicit opacity")
    func decodesExplicitOpacity() throws {
        let config = try decodeConfig(#"{"notchPanelOpacity": 0.85, "sites": []}"#)

        #expect(config.notchPanelOpacity == 0.85)
    }

    @Test("out-of-range opacities are clamped instead of failing")
    func outOfRangeOpacityIsClamped() throws {
        let low = try decodeConfig(#"{"notchPanelOpacity": 0.01, "sites": []}"#)
        let high = try decodeConfig(#"{"notchPanelOpacity": 7, "sites": []}"#)

        #expect(low.notchPanelOpacity == 0.2)
        #expect(high.notchPanelOpacity == 1.0)
    }

    @Test("a wrong opacity value type falls back to the default")
    func wrongOpacityTypeFallsBack() throws {
        let config = try decodeConfig(#"{"notchPanelOpacity": "dark", "sites": []}"#)

        #expect(config.notchPanelOpacity == 0.6)
    }

    @Test("opacity round-trips through encoding")
    func opacityRoundTripsThroughEncoding() throws {
        let original = Config(notchPanelOpacity: 0.35, sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchPanelOpacity == 0.35)
    }

    @Test("content color defaults to black when the key is missing")
    func colorDefaultsToBlack() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchPanelColorHex == "#000000")
    }

    @Test("decodes a custom content color")
    func decodesCustomColor() throws {
        let config = try decodeConfig(##"{"notchPanelColorHex": "#1A2B3C", "sites": []}"##)

        #expect(config.notchPanelColorHex == "#1A2B3C")
    }

    @Test("malformed color strings fall back to black")
    func malformedColorFallsBack() throws {
        let noHash = try decodeConfig(#"{"notchPanelColorHex": "123456", "sites": []}"#)
        let short = try decodeConfig(##"{"notchPanelColorHex": "#12", "sites": []}"##)
        let junk = try decodeConfig(##"{"notchPanelColorHex": "#GGHHII", "sites": []}"##)

        #expect(noHash.notchPanelColorHex == "#000000")
        #expect(short.notchPanelColorHex == "#000000")
        #expect(junk.notchPanelColorHex == "#000000")
    }

    @Test("content color round-trips through encoding")
    func colorRoundTripsThroughEncoding() throws {
        let original = Config(notchPanelColorHex: "#33445A", sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchPanelColorHex == "#33445A")
    }

    @Test("widgets default to the three launcher sections plus Screenshots")
    func widgetsDefaultToLauncherSections() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(
            config.notchWidgets
                == NotchWidget.normalizedSlots([.sites, .apps, .folders, .screenshots]))
        #expect(!config.didMigrateScriptsWidget)
    }

    @Test("a removed Scripts slot becomes Screenshots")
    func scriptsSlotMigratesToScreenshots() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["sites", "apps", "folders", "scripts"], "sites": []}"#)

        #expect(
            config.notchWidgets
                == NotchWidget.normalizedSlots([.sites, .apps, .folders, .screenshots]))
        #expect(config.didMigrateScriptsWidget)
        #expect(config.needsShellRemovalMigration)
    }

    @Test("a removed Scripts slot becomes empty when Screenshots is already placed")
    func scriptsSlotMigratesToEmptyWhenScreenshotsPlaced() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["scripts", "screenshots", "sites", "apps"], "sites": []}"#)

        #expect(
            config.notchWidgets
                == NotchWidget.normalizedSlots([.none, .screenshots, .sites, .apps]))
        #expect(config.didMigrateScriptsWidget)
    }

    @Test("decodes explicit widget slots")
    func decodesExplicitWidgets() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["screenshots", "sites", "apps", "none"], "sites": []}"#)

        #expect(
            config.notchWidgets
                == NotchWidget.normalizedSlots([.screenshots, .sites, .apps, .none]))
    }

    @Test("decodes the drop widget")
    func decodesDropWidget() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["drop", "sites", "none", "none"], "sites": []}"#)

        #expect(config.notchWidgets == NotchWidget.normalizedSlots([.drop, .sites, .none, .none]))
    }

    @Test("unknown widget names are dropped and slots padded to four")
    func unknownWidgetsDroppedAndPadded() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["sites", "hologram", "screenshots"], "sites": []}"#)

        #expect(
            config.notchWidgets
                == NotchWidget.normalizedSlots([.sites, .screenshots, .none, .none]))
    }

    @Test("all unknown widgets fall back to usable defaults")
    func allUnknownWidgetsFallBackToDefaults() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["future-one", "future-two"], "sites": []}"#)

        #expect(config.notchWidgets == NotchWidget.defaultSlots)
    }

    @Test("duplicate non-empty widgets are removed while empty slots remain")
    func duplicateWidgetsAreNormalized() {
        let slots = NotchWidget.normalizedSlots([.sites, .sites, .none, .none, .apps])

        #expect(slots == NotchWidget.normalizedSlots([.sites, .none, .none, .apps]))
    }

    @Test("the notch has six slots")
    func sixSlots() {
        #expect(NotchWidget.slotCount == 6)
        #expect(NotchWidget.defaultSlots == [.sites, .apps, .folders, .screenshots, .none, .none])
    }

    @Test("a 2.1 twelve-slot layout keeps every widget by moving late ones into gaps")
    func twelveSlotLayoutIsCompacted() throws {
        let config = try decodeConfig(
            #"""
            {"notchWidgets": ["screenshots", "sites", "apps", "folders", "none", "none",
                              "none", "none", "mirror", "none", "note", "none"],
             "sites": []}
            """#)

        #expect(config.notchWidgets == [.screenshots, .sites, .apps, .folders, .mirror, .note])
    }

    @Test("widgets beyond the six slots are dropped only when no gap is left")
    func overflowWithoutGapsIsDropped() {
        let slots = NotchWidget.normalizedSlots([
            .sites, .apps, .folders, .screenshots, .mirror, .note, .drop,
        ])

        #expect(slots == [.sites, .apps, .folders, .screenshots, .mirror, .note])
    }

    @Test("a legacy four-slot layout keeps its order with two empty slots")
    func legacyFourSlotsKeepOrder() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["sites", "apps", "folders", "screenshots"], "sites": []}"#)

        #expect(config.notchWidgets == [.sites, .apps, .folders, .screenshots, .none, .none])
    }

    @Test("widgets round-trip through encoding")
    func widgetsRoundTripThroughEncoding() throws {
        let original = Config(
            notchWidgets: [.screenshots, .sites, .none, .folders], sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(
            decoded.notchWidgets
                == NotchWidget.normalizedSlots([.screenshots, .sites, .none, .folders]))
    }
}
