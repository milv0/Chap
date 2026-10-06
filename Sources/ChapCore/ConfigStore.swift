import Foundation

public struct ConfigLoadResult {
    public let config: Config
    public let displayWarnings: [ImportWarning]
    public let didAutoSaveDisplayMigration: Bool
    /// 2.1 Shell 제거 마이그레이션으로 걸러낸 항목 이름. 없으면 빈 배열.
    public var removedShellSiteNames: [String] = []
    /// 마이그레이션 전 원본을 보관한 경로. 백업에 실패했거나 필요 없으면 nil.
    public var shellRemovalBackupPath: String? = nil
}

public enum ConfigStoreError: LocalizedError {
    case readFailed(path: String)
    /// 읽지 못한 원본은 `preservedCopyPath`에 그대로 보존된다(기본 설정 저장이 덮어써도 남는다).
    case decodeFailed(Error, preservedCopyPath: String?)
    case backupFailed(path: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .readFailed(let path):
            return "Failed to read config file at \(path)."
        case .decodeFailed(let error, _):
            return error.localizedDescription
        case .backupFailed(let path, let underlying):
            return "Failed to create config backup at \(path): \(underlying.localizedDescription)"
        }
    }
}

public struct ConfigStore {
    public let configPath: String
    public let legacyConfigPath: String

    public var backupPath: String {
        configPath + ".bak"
    }

    /// Shell 제거 전 원본 설정 보관 경로. 일반 `.bak`은 다음 저장 때 덮어쓰이므로 따로 둔다.
    public var shellRemovalBackupPath: String {
        configPath + ".shell-scripts.bak"
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
            throw ConfigStoreError.decodeFailed(
                error, preservedCopyPath: preserveUnreadableConfig(data))
        }

        var config = decodedConfig
        let shellBackupPath = migrateShellRemovalIfNeeded(config, originalData: data)
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
        if didNormalizeShortcuts || didChangeDisplaySelection
            || (config.needsShellRemovalMigration && shellBackupPath != nil)
        {
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
            didAutoSaveDisplayMigration: didAutoSaveDisplayMigration,
            removedShellSiteNames: config.removedShellSiteNames,
            shellRemovalBackupPath: shellBackupPath)
    }

    /// Shell 항목·Scripts 칸이 남은 원본을 전용 백업으로 한 번 보관한다.
    /// 백업이 끝나야만 호출자가 파일을 다시 써서 Shell 흔적을 지운다.
    /// 백업에 실패하면 nil을 돌려주고 원본 파일은 그대로 둔다.
    private func migrateShellRemovalIfNeeded(_ config: Config, originalData: Data) -> String? {
        guard config.needsShellRemovalMigration else { return nil }
        let path = shellRemovalBackupPath
        // 이미 보관본이 있으면 덮어쓰지 않는다: 가장 오래된 원본이 가장 완전하다.
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
            !isDirectory.boolValue
        {
            return path
        }
        do {
            try originalData.write(to: URL(fileURLWithPath: path), options: .atomic)
            return path
        } catch {
            Log.config.error(
                "Failed to back up config before Shell removal: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
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

    /// 읽지 못한 설정 원본을 `~/.chap.json.unreadable-<시각>`으로 남긴다. 앱은 기본 설정으로 시작하고,
    /// 이후 저장이 `.chap.json`과 `.bak`을 덮어써도 사용자의 원래 설정은 이 사본에 남는다.
    func preserveUnreadableConfig(_ data: Data, now: Date = Date()) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let path = configPath + ".unreadable-" + formatter.string(from: now)
        guard !FileManager.default.fileExists(atPath: path) else { return path }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            return path
        } catch {
            return nil
        }
    }

    public func save(_ config: Config) throws {
        try write(config, createBackup: true)
    }

    private func write(_ config: Config, createBackup: Bool) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        if createBackup, FileManager.default.fileExists(atPath: configPath) {
            do {
                let currentData = try Data(contentsOf: URL(fileURLWithPath: configPath))
                try currentData.write(
                    to: URL(fileURLWithPath: backupPath), options: .atomic)
            } catch {
                // A save without a trustworthy previous version defeats the backup contract.
                // Abort before replacing the primary config so the last known-good file survives.
                throw ConfigStoreError.backupFailed(path: backupPath, underlying: error)
            }
        }
        try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }
}
