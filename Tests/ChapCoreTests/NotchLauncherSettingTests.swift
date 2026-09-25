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

    @Test("style defaults to black when the key is missing")
    func styleDefaultsToBlack() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.notchPanelStyle == .black)
    }

    @Test("decodes the iceberg style")
    func decodesIcebergStyle() throws {
        let config = try decodeConfig(#"{"notchPanelStyle": "iceberg", "sites": []}"#)

        #expect(config.notchPanelStyle == .iceberg)
    }

    @Test("an unknown style string falls back to black instead of failing")
    func unknownStyleFallsBackToBlack() throws {
        let config = try decodeConfig(#"{"notchPanelStyle": "lava", "sites": []}"#)

        #expect(config.notchPanelStyle == .black)
    }

    @Test("style round-trips through encoding")
    func styleRoundTripsThroughEncoding() throws {
        let original = Config(notchPanelStyle: .iceberg, sites: [])

        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(original))

        #expect(decoded.notchPanelStyle == .iceberg)
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

    @Test("decodes the drop shelf widget")
    func decodesShelfWidget() throws {
        let config = try decodeConfig(
            #"{"notchWidgets": ["shelf", "sites", "none", "none"], "sites": []}"#)

        #expect(config.notchWidgets == [.shelf, .sites, .none, .none])
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
