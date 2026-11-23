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

@Suite("Notch glow moments")
struct NotchGlowMomentTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("only a newer, recent file counts as an arrival")
    func arrivals() {
        #expect(NotchGlowPolicy.isNewArrival(previous: nil, newest: now, now: now) == false)
        #expect(NotchGlowPolicy.isNewArrival(previous: now - 60, newest: now - 1, now: now))
        #expect(NotchGlowPolicy.isNewArrival(previous: now - 1, newest: now - 1, now: now) == false)
        // 오래된 파일이 옮겨져 들어온 것은 새 파일이 아니다.
        #expect(
            NotchGlowPolicy.isNewArrival(previous: now - 9000, newest: now - 600, now: now) == false
        )
    }

    @Test("arrival and window glows are on by default and round-trip")
    func momentSettings() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.notchGlowArrivals && missing.notchGlowSnaps)
        let off = Config(notchGlowArrivals: false, notchGlowSnaps: false, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(off))
        #expect(!decoded.notchGlowArrivals && !decoded.notchGlowSnaps)
    }

    @Test("a finished timer glows longest and brightest, a window snap is the shortest")
    func momentSizes() {
        #expect(NotchGlowMoment.timerFinished.duration > NotchGlowMoment.preview.duration)
        #expect(NotchGlowMoment.snap.duration < NotchGlowMoment.arrival.duration)
        #expect(NotchGlowMoment.timerFinished.lineWidth > NotchGlowMoment.arrival.lineWidth)
    }

    @Test(
        "an end glow is shorter and thinner than a start glow, and a finished timer outshines both")
    func startAndEnd() {
        #expect(NotchGlowMoment.ended.duration < NotchGlowMoment.started.duration)
        #expect(NotchGlowMoment.ended.lineWidth < NotchGlowMoment.started.lineWidth)
        #expect(NotchGlowMoment.timerFinished.duration > NotchGlowMoment.started.duration)
        #expect(NotchGlowMoment.timerFinished.lineWidth > NotchGlowMoment.started.lineWidth)
    }
}
