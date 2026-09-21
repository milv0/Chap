import Foundation
import Testing

@testable import Chap

@Suite("Hidden Menu Launch Types")
struct HiddenMenuLaunchTypesTests {
    private func decodeConfig(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    @Test("defaults to empty when the key is missing")
    func defaultsToEmptyWhenMissing() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.hiddenMenuLaunchTypes.isEmpty)
    }

    @Test("decodes known launch types")
    func decodesKnownTypes() throws {
        let config = try decodeConfig(
            #"{"hiddenMenuLaunchTypes": ["shell", "finder"], "sites": []}"#)

        #expect(config.hiddenMenuLaunchTypes == [.shell, .finder])
    }

    @Test("unknown type strings are ignored")
    func unknownTypesAreIgnored() throws {
        let config = try decodeConfig(
            #"{"hiddenMenuLaunchTypes": ["shell", "hologram"], "sites": []}"#)

        #expect(config.hiddenMenuLaunchTypes == [.shell])
    }

    @Test("round-trips through encoding")
    func roundTripsThroughEncoding() throws {
        let original = Config(hiddenMenuLaunchTypes: [.app, .url], sites: [])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)

        #expect(decoded.hiddenMenuLaunchTypes == [.app, .url])
    }

    @Test("encodes hidden types in stable declaration order")
    func encodesInStableOrder() throws {
        let data = try JSONEncoder().encode(
            Config(hiddenMenuLaunchTypes: [.shell, .url], sites: []))
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains(#""hiddenMenuLaunchTypes":["url","shell"]"#))
    }

    @Test("view model detects hidden menu type changes")
    func viewModelDetectsChanges() {
        let vm = SettingsViewModel(sites: [
            Site(name: "GitHub", url: "https://github.com/", width: 800, height: 600)
        ])

        vm.hiddenMenuLaunchTypes.insert(.shell)

        #expect(vm.hasChanges == true)
    }
}
