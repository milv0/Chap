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
}
