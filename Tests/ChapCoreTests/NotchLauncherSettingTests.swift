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

    @Test("widgets default to the four launcher sections when the key is missing")
    func widgetsDefaultToLauncherSections() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchWidgets == [.sites, .apps, .folders, .scripts])
    }

    @Test("decodes explicit widget slots")
    func decodesExplicitWidgets() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["screenshots", "sites", "apps", "none"], "sites": []}"#)

        #expect(config.notchWidgets == [.screenshots, .sites, .apps, .none])
    }

    @Test("decodes the drop widget")
    func decodesDropWidget() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["drop", "sites", "none", "none"], "sites": []}"#)

        #expect(config.notchWidgets == [.drop, .sites, .none, .none])
    }

    @Test("unknown widget names are dropped and slots padded to four")
    func unknownWidgetsDroppedAndPadded() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["sites", "hologram", "screenshots"], "sites": []}"#)

        #expect(config.notchWidgets == [.sites, .screenshots, .none, .none])
    }

    @Test("more than four widgets are capped at four slots")
    func widgetsCappedAtFour() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["sites", "apps", "folders", "scripts", "screenshots"], "sites": []}"#
        )

        #expect(config.notchWidgets == [.sites, .apps, .folders, .scripts])
    }

    @Test("widgets round-trip through encoding")
    func widgetsRoundTripThroughEncoding() throws {
        let original = Config(
            notchWidgets: [.screenshots, .sites, .none, .scripts], sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchWidgets == [.screenshots, .sites, .none, .scripts])
    }
}
