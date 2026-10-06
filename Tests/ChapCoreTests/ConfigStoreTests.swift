import Foundation
import Testing

@testable import Chap

@Suite("ConfigStore")
struct ConfigStoreTests {
    private func makeTemporaryStore() throws -> (store: ConfigStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapConfigStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configPath = directory.appendingPathComponent("chap.json").path
        let legacyPath = directory.appendingPathComponent("quickaccess.json").path
        return (ConfigStore(configPath: configPath, legacyConfigPath: legacyPath), directory)
    }

    @Test("an unknown status bar icon from a newer version keeps the rest of the config")
    func unknownStatusBarIconIsTolerated() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let json = #"""
            {"statusBarIcon":"sparkle-from-the-future","notchLauncherEnabled":true,
             "sites":[{"name":"Keep","url":"https://keep.example","width":800,"height":600}]}
            """#
        try Data(json.utf8).write(to: URL(fileURLWithPath: fixture.store.configPath))

        let config = try fixture.store.load(connectedDisplays: []).config

        #expect(config.statusBarIcon == .default)
        #expect(config.notchLauncherEnabled)
        #expect(config.sites.map(\.name) == ["Keep"])
    }

    @Test("an unreadable config is preserved byte for byte before Chap falls back to defaults")
    func unreadableConfigIsPreserved() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = Data(#"{"sites": "not-an-array", "mine": "precious"}"#.utf8)
        try original.write(to: URL(fileURLWithPath: fixture.store.configPath))

        var preserved: String?
        do {
            _ = try fixture.store.load(connectedDisplays: [])
            Issue.record("expected a decode failure")
        } catch ConfigStoreError.decodeFailed(_, let path) {
            preserved = path
        }

        let path = try #require(preserved)
        #expect(path.hasPrefix(fixture.store.configPath + ".unreadable-"))
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == original)

        // 기본 설정을 두 번 저장해 .chap.json과 .bak을 모두 덮어써도 사본은 남는다.
        try fixture.store.save(.default)
        try fixture.store.save(.default)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == original)
    }

    @Test("save writes config and backs up previous file")
    func saveWritesBackup() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let first = Config(sites: [
            Site(name: "A", url: "https://a.com", width: 800, height: 600)
        ])
        let second = Config(sites: [
            Site(name: "B", url: "https://b.com", width: 900, height: 700)
        ])

        try fixture.store.save(first)
        try fixture.store.save(second)

        let saved = try JSONDecoder().decode(
            Config.self, from: Data(contentsOf: URL(fileURLWithPath: fixture.store.configPath)))
        let backup = try JSONDecoder().decode(
            Config.self, from: Data(contentsOf: URL(fileURLWithPath: fixture.store.backupPath)))
        #expect(saved.sites == second.sites)
        #expect(backup.sites == first.sites)
    }

    @Test("backup failure aborts save and preserves primary config")
    func backupFailurePreservesPrimary() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let first = Config(sites: [
            Site(name: "First", url: "https://first.com", width: 800, height: 600)
        ])
        let second = Config(sites: [
            Site(name: "Second", url: "https://second.com", width: 900, height: 700)
        ])
        try fixture.store.save(first)
        try FileManager.default.createDirectory(
            atPath: fixture.store.backupPath, withIntermediateDirectories: true)

        #expect(throws: ConfigStoreError.self) {
            try fixture.store.save(second)
        }

        let preserved = try JSONDecoder().decode(
            Config.self,
            from: Data(contentsOf: URL(fileURLWithPath: fixture.store.configPath)))
        #expect(preserved.sites == first.sites)
    }

    @Test("load completes displayName for connected displayIdentifier and persists it")
    func loadCompletesDisplayName() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let config = Config(sites: [
            Site(
                name: "Work", url: "https://work.com", width: 800, height: 600,
                displayName: nil, displayIdentifier: "UUID-WORK")
        ])
        try fixture.store.save(config)

        let result = try fixture.store.load(connectedDisplays: [
            DisplayMatchCandidate(identifier: "UUID-WORK", name: "Studio Display")
        ])

        let saved = try JSONDecoder().decode(
            Config.self, from: Data(contentsOf: URL(fileURLWithPath: fixture.store.configPath)))
        #expect(result.didAutoSaveDisplayMigration)
        #expect(result.config.sites[0].displayName == "Studio Display")
        #expect(saved.sites[0].displayName == "Studio Display")
    }

    @Test("load persists shortcut normalization")
    func loadPersistsShortcutNormalization() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let config = Config(sites: [
            Site(
                name: "A", url: "https://a.com", width: 800, height: 600,
                shortcut: "AB"),
            Site(
                name: "B", url: "https://b.com", width: 800, height: 600,
                shortcut: "K"),
        ])
        try fixture.store.save(config)

        let result = try fixture.store.load(connectedDisplays: [])

        let saved = try JSONDecoder().decode(
            Config.self, from: Data(contentsOf: URL(fileURLWithPath: fixture.store.configPath)))
        #expect(result.config.sites.map(\.shortcut) == [nil, "K"])
        #expect(saved.sites.map(\.shortcut) == [nil, "K"])
    }

    @Test("stripLegacyFields removes legacy config keys")
    func stripLegacyFields() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let legacyJSON = """
            {
              "showGhostWindow": false,
              "runInBackground": false,
              "sites": [
                {
                  "name": "A",
                  "url": "https://a.com",
                  "width": 800,
                  "height": 600,
                  "x": 10,
                  "y": 20,
                  "hotkey": "A"
                }
              ]
            }
            """
        try legacyJSON.write(toFile: fixture.store.configPath, atomically: true, encoding: .utf8)
        let result = try fixture.store.load(connectedDisplays: [])

        let didStrip = try fixture.store.stripLegacyFieldsIfNeeded(using: result.config)

        let rawJSON = try #require(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: URL(fileURLWithPath: fixture.store.configPath)))
                as? [String: Any])
        let sites = try #require(rawJSON["sites"] as? [[String: Any]])
        #expect(didStrip)
        #expect(rawJSON["showGhostWindow"] == nil)
        #expect(rawJSON["runInBackground"] == nil)
        #expect(sites[0]["x"] == nil)
        #expect(sites[0]["y"] == nil)
        #expect(sites[0]["hotkey"] == nil)
        #expect(sites[0]["shortcut"] as? String == "A")
    }
}
