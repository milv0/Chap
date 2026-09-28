import Foundation
import Testing

@testable import Chap

@Suite("Shell removal migration")
struct ShellRemovalMigrationTests {
    private static let mixedConfigJSON = #"""
        {
          "notchWidgets": ["sites", "apps", "folders", "scripts"],
          "sites": [
            {"name": "GitHub", "url": "https://github.com/", "width": 800, "height": 600,
             "launchType": "url"},
            {"name": "Deploy", "url": "", "width": 800, "height": 600,
             "launchType": "shell", "script": "make deploy"},
            {"name": "Downloads", "url": "", "width": 1000, "height": 400,
             "launchType": "finder", "folderPath": "~/Downloads"},
            {"url": "", "width": 800, "height": 600, "launchType": "shell", "script": "ls"}
          ]
        }
        """#

    private func makeTemporaryStore() throws -> (store: ConfigStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapShellRemovalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configPath = directory.appendingPathComponent("chap.json").path
        let legacyPath = directory.appendingPathComponent("quickaccess.json").path
        return (ConfigStore(configPath: configPath, legacyConfigPath: legacyPath), directory)
    }

    private func write(_ json: String, to path: String) throws {
        try Data(json.utf8).write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Decoding

    @Test("decoding drops Shell sites, keeps the rest in order, and records their names")
    func decodingDropsShellSites() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(Self.mixedConfigJSON.utf8))

        #expect(config.sites.map(\.name) == ["GitHub", "Downloads"])
        #expect(config.removedShellSiteNames == ["Deploy", "Untitled"])
        #expect(config.needsShellRemovalMigration)
    }

    @Test("a config without Shell traces needs no migration")
    func cleanConfigNeedsNoMigration() throws {
        let config = try JSONDecoder().decode(
            Config.self,
            from: Data(
                #"{"notchWidgets": ["sites", "screenshots"], "sites": []}"#.utf8))

        #expect(config.removedShellSiteNames.isEmpty)
        #expect(!config.needsShellRemovalMigration)
    }

    @Test("migration markers are never written back to the config file")
    func markersAreNotEncoded() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(Self.mixedConfigJSON.utf8))
        let json = try #require(String(data: JSONEncoder().encode(config), encoding: .utf8))

        #expect(!json.contains("removedShellSiteNames"))
        #expect(!json.contains("didMigrateScriptsWidget"))
        #expect(!json.contains(#""shell""#))
        #expect(!json.contains(#""scripts""#))
        #expect(!json.contains(#""script""#))
    }

    // MARK: - ConfigStore

    @Test("load backs up the original once and rewrites the config without Shell traces")
    func loadBacksUpAndRewrites() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let store = fixture.store
        try write(Self.mixedConfigJSON, to: store.configPath)

        let first = try store.load(connectedDisplays: [])

        #expect(first.removedShellSiteNames == ["Deploy", "Untitled"])
        #expect(first.shellRemovalBackupPath == store.shellRemovalBackupPath)
        let backup = try String(contentsOfFile: store.shellRemovalBackupPath, encoding: .utf8)
        #expect(backup == Self.mixedConfigJSON)
        let rewritten = try String(contentsOfFile: store.configPath, encoding: .utf8)
        #expect(!rewritten.contains(#""shell""#))
        #expect(!rewritten.contains(#""scripts""#))

        let second = try store.load(connectedDisplays: [])
        #expect(second.removedShellSiteNames.isEmpty)
        #expect(second.shellRemovalBackupPath == nil)
        #expect(second.config.sites.map(\.name) == ["GitHub", "Downloads"])
        #expect(second.config.notchWidgets == [.sites, .apps, .folders, .screenshots])
    }

    @Test("an existing Shell backup is never overwritten")
    func existingBackupIsPreserved() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let store = fixture.store
        try write("original", to: store.shellRemovalBackupPath)
        try write(Self.mixedConfigJSON, to: store.configPath)

        let result = try store.load(connectedDisplays: [])

        #expect(result.shellRemovalBackupPath == store.shellRemovalBackupPath)
        #expect(
            try String(contentsOfFile: store.shellRemovalBackupPath, encoding: .utf8)
                == "original")
    }

    @Test("a failed backup leaves the original config file untouched")
    func failedBackupLeavesConfigUntouched() throws {
        let fixture = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let store = fixture.store
        // A directory at the backup path makes the backup write fail.
        try FileManager.default.createDirectory(
            atPath: store.shellRemovalBackupPath, withIntermediateDirectories: true)
        try write(Self.mixedConfigJSON, to: store.configPath)

        let result = try store.load(connectedDisplays: [])

        #expect(result.shellRemovalBackupPath == nil)
        #expect(result.removedShellSiteNames == ["Deploy", "Untitled"])
        #expect(result.config.sites.map(\.name) == ["GitHub", "Downloads"])
        #expect(
            try String(contentsOfFile: store.configPath, encoding: .utf8)
                == Self.mixedConfigJSON)
    }

    // MARK: - Import

    @Test("import rejects a file that contains Shell sites")
    func importRejectsShellSites() {
        let result = ConfigImportProcessor.process(
            data: Data(Self.mixedConfigJSON.utf8), connectedDisplays: [])

        guard case .unsupportedShellSites(let names) = result else {
            Issue.record("Expected unsupportedShellSites, got \(result)")
            return
        }
        #expect(names == ["Deploy", "Untitled"])
    }

    @Test("import accepts a file whose only Shell trace is a Scripts slot")
    func importAcceptsScriptsSlotOnly() {
        let json = #"""
            {"notchWidgets": ["scripts"],
             "sites": [{"name": "GitHub", "url": "https://github.com/", "width": 800,
                        "height": 600, "launchType": "url"}]}
            """#
        let result = ConfigImportProcessor.process(
            data: Data(json.utf8), connectedDisplays: [])

        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
    }

    // MARK: - Notice

    @Test("notice lists at most four names and summarizes the rest")
    func noticeTruncatesNames() {
        let list = ShellRemovalNotice.nameList(["A", "B", "C", "D", "E", "F"])

        #expect(list == "• A\n• B\n• C\n• D\n• and 2 more")
    }

    @Test("migration notice shows the backup path relative to home")
    func migrationNoticeShowsBackup() {
        let path = NSHomeDirectory() + "/.chap.json.shell-scripts.bak"
        let message = ShellRemovalNotice.migrationMessage(
            removedNames: ["Deploy"], backupPath: path)

        #expect(message.contains("• Deploy"))
        #expect(message.contains("~/.chap.json.shell-scripts.bak"))
    }

    @Test("migration notice explains an unchanged file when the backup failed")
    func migrationNoticeWithoutBackup() {
        let message = ShellRemovalNotice.migrationMessage(
            removedNames: ["Deploy"], backupPath: nil)

        #expect(message.contains("left the file unchanged"))
        #expect(!message.contains("was saved to"))
    }

    @Test("import rejection notice names the Shell items and states nothing changed")
    func importRejectionNotice() {
        let message = ShellRemovalNotice.importRejectionMessage(removedNames: ["Deploy"])

        #expect(message.contains("• Deploy"))
        #expect(message.contains("Nothing was changed."))
    }
}
