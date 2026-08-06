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
