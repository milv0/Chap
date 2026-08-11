import Foundation
import Testing

@testable import Chap

@Suite("App Lifecycle Support")
struct AppLifecycleSupportTests {
    @Test("restart passes the bundle path as a positional shell argument")
    func restartArgumentsDoNotInterpolateAppPath() {
        let appPath = #"/Applications/Chap "Preview" $HOME.app"#

        let arguments = AppLifecycleSupport.restartTaskArguments(appPath: appPath)

        let expectedArguments = [
            "-c",
            "sleep 1; open -- \"$1\"",
            "chap-restart",
            appPath,
        ]

        #expect(arguments == expectedArguments)
    }

    @Test("removes existing config and backup files")
    func removesConfigAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapLifecycleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configURL = directory.appendingPathComponent("chap.json")
        let backupURL = directory.appendingPathComponent("chap.json.bak")
        try Data("config".utf8).write(to: configURL)
        try Data("backup".utf8).write(to: backupURL)

        try AppLifecycleSupport.removeConfigurationFiles(configPath: configURL.path)

        #expect(!FileManager.default.fileExists(atPath: configURL.path))
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
    }

    @Test("missing config files do not prevent cleanup")
    func ignoresAbsentConfigFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapLifecycleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try AppLifecycleSupport.removeConfigurationFiles(
            configPath: directory.appendingPathComponent("chap.json").path)
    }
}
