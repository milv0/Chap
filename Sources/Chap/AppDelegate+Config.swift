import Cocoa
import os

// MARK: - Config handling

extension AppDelegate {
    // MARK: - Config migration

    /// 기존 ~/.quickaccess.json → ~/.chap.json 마이그레이션
    func migrateConfigIfNeeded() {
        do {
            if try configStore.migrateLegacyConfigPathIfNeeded() {
                Log.config.info("Migrated config from ~/.quickaccess.json to ~/.chap.json")
            }
        } catch {
            Log.config.error(
                "Failed to migrate legacy config: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 설정 파일에 남아 있는 레거시 필드(x, y, hotkey, showGhostWindow 등)를 제거.
    /// loadConfig() 후 호출하면 decode→encode 과정에서 레거시 키가 자동 탈락하므로,
    /// 파일 원본에 해당 키가 있으면 한 번 덮어써서 정리한다.
    func stripLegacyConfigFields() {
        do {
            if try configStore.stripLegacyFieldsIfNeeded(using: config) {
                Log.config.info("Stripped legacy fields from config file")
            }
        } catch {
            Log.config.error(
                "Failed to strip legacy fields: \(error.localizedDescription, privacy: .public)")
        }
    }

    func copyDefaultConfigIfNeeded() {
        do {
            _ = try configStore.createDefaultConfigIfNeeded()
        } catch {
            Log.config.error(
                "Failed to write default config: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func loadConfig() {
        let connectedDisplays = NSScreen.screens.map {
            DisplayMatchCandidate(identifier: displayUUID(for: $0), name: $0.localizedName)
        }
        do {
            let result = try configStore.load(connectedDisplays: connectedDisplays)
            config = result.config
            if result.didAutoSaveDisplayMigration {
                Log.config.info("Auto-saved display UUID migration")
            }
            for warning in result.displayWarnings {
                Log.config.warning(
                    "Display migration: \(warning.message, privacy: .public)")
            }
        } catch ConfigStoreError.readFailed {
            Log.config.error("Failed to read config file at \(self.configPath, privacy: .public)")
            config = .default
        } catch {
            Log.config.error("Config decode error: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Config file is corrupted"
                alert.informativeText =
                    "~/.chap.json을 읽을 수 없어 기본 설정을 사용합니다.\n백업 파일: ~/.chap.json.bak\n\nError: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
            }
            config = .default
        }
    }

    @objc func reloadConfig() {
        loadConfig()
        buildMenu()
    }
}
