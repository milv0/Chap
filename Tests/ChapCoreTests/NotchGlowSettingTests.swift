import Foundation
import Testing

@testable import Chap

@Suite("Notch glow setting")
struct NotchGlowSettingTests {
    @Test("older configs turn the glow on with the colorful palette")
    func missingKeysUseDefaults() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(config.notchGlowEnabled)
        #expect(config.notchGlowPalette == .colorful)
    }

    @Test("an unknown palette falls back to colorful instead of failing the whole config")
    func unknownPaletteFallsBack() throws {
        let json = #"{"sites": [], "notchGlowEnabled": false, "notchGlowPalette": "neon"}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(!config.notchGlowEnabled)
        #expect(config.notchGlowPalette == .colorful)
    }

    @Test("the glow switch and palette round-trip through the config file")
    func roundTrips() throws {
        let saved = Config(notchGlowEnabled: false, notchGlowPalette: .chap, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(saved))
        #expect(decoded.notchGlowEnabled == false)
        #expect(decoded.notchGlowPalette == .chap)
    }

    @Test("changing the glow marks Settings as changed until it saves")
    func viewModelTracksChanges() {
        let vm = SettingsViewModel(config: Config(sites: []))
        #expect(!vm.hasChanges)
        vm.notchGlowPalette = .chap
        #expect(vm.hasChanges)
        #expect(vm.globalsConfig.notchGlowPalette == .chap)
        vm.markGlobalsSaved()
        #expect(!vm.hasChanges)
        vm.notchGlowEnabled = false
        #expect(vm.hasChanges)
    }

    @Test("each palette has colors and the Chap palette is built around Chap blue")
    func palettes() {
        for palette in NotchGlowPalette.allCases {
            #expect(palette.colors.count >= 5)
        }
        #expect(NotchGlowPalette.chap.colors.contains(0x3664FF))
    }
}
