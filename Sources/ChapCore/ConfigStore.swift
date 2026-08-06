import Foundation

public struct ConfigLoadResult {
    public let config: Config
    public let displayWarnings: [ImportWarning]
    public let didAutoSaveDisplayMigration: Bool
}

public enum ConfigStoreError: LocalizedError {
    case readFailed(path: String)
    case decodeFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .readFailed(let path):
            return "Failed to read config file at \(path)."
        case .decodeFailed(let error):
            return error.localizedDescription
        }
    }
}

public struct ConfigStore {
    public let configPath: String
    public let legacyConfigPath: String

    public var backupPath: String {
        configPath + ".bak"
    }

    public init(
        configPath: String = Defaults.configPath,
        legacyConfigPath: String = NSString(string: "~/.quickaccess.json").expandingTildeInPath
    ) {
        self.configPath = configPath
        self.legacyConfigPath = legacyConfigPath
    }

    public static let seedConfig = Config(sites: [
        Site(
            name: "Google", url: "https://www.google.com/", width: 600, height: 400,
            launchType: .url),
        Site(
            name: "GitHub", url: "https://github.com/", width: Defaults.defaultWidth,
            height: Defaults.defaultHeight, launchType: .url),
        Site(
            name: "Downloads", url: "", width: 1000, height: 400, launchType: .finder,
            folderPath: "~/Downloads"),
    ])

    @discardableResult
    public func migrateLegacyConfigPathIfNeeded() throws -> Bool {
        guard FileManager.default.fileExists(atPath: legacyConfigPath),
            !FileManager.default.fileExists(atPath: configPath)
        else {
            return false
        }
        try FileManager.default.moveItem(atPath: legacyConfigPath, toPath: configPath)
        return true
    }

    @discardableResult
    public func createDefaultConfigIfNeeded() throws -> Bool {
        guard !FileManager.default.fileExists(atPath: configPath) else { return false }
        try write(ConfigStore.seedConfig, createBackup: false)
        return true
    }

    public func load(connectedDisplays: [DisplayMatchCandidate]) throws -> ConfigLoadResult {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            throw ConfigStoreError.readFailed(path: configPath)
        }

        let decodedConfig: Config
        do {
            decodedConfig = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            throw ConfigStoreError.decodeFailed(error)
        }

        var config = decodedConfig
        let sitesBeforeShortcutNormalization = config.sites
        config.sites = sanitizedShortcuts(for: config.sites)
        let didNormalizeShortcuts = config.sites != sitesBeforeShortcutNormalization

        let migrationResult = migrateDisplayIdentifiers(
            sites: config.sites, connectedDisplays: connectedDisplays)
        let didChangeDisplaySelection = migrationResult.sites != config.sites
        var didAutoSaveDisplayMigration = false
        if didChangeDisplaySelection {
            config.sites = migrationResult.sites
        }
        if didNormalizeShortcuts || didChangeDisplaySelection {
            do {
                try save(config)
                didAutoSaveDisplayMigration = didChangeDisplaySelection
            } catch {
                Log.config.error(
                    "Failed to auto-save config normalization: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return ConfigLoadResult(
            config: config,
            displayWarnings: migrationResult.warnings,
            didAutoSaveDisplayMigration: didAutoSaveDisplayMigration)
    }

    @discardableResult
    public func stripLegacyFieldsIfNeeded(using config: Config) throws -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
            let rawJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sites = rawJSON["sites"] as? [[String: Any]]
        else {
            return false
        }

        let legacySiteKeys: Set<String> = ["x", "y", "hotkey"]
        let hasLegacyFields =
            sites.contains { site in
                !legacySiteKeys.isDisjoint(with: site.keys)
            } || rawJSON.keys.contains("showGhostWindow")
            || rawJSON.keys.contains("runInBackground")

        guard hasLegacyFields else { return false }
        try save(config)
        return true
    }

    public func save(_ config: Config) throws {
        try write(config, createBackup: true)
    }

    private func write(_ config: Config, createBackup: Bool) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        if createBackup {
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: configPath, toPath: backupPath)
        }
        try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }
}
