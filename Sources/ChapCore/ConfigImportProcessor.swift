import Foundation

struct ProcessedConfigImport {
    let config: Config
    let fixes: [ImportFix]
    let warnings: [ImportWarning]
}

enum ConfigImportProcessingResult {
    case success(ProcessedConfigImport)
    case blocked(Config, [ImportBlockingIssue])
    case decodeFailed(String)
}

/// JSON decode와 안전한 import normalization을 UI에서 분리한 순수 처리기.
enum ConfigImportProcessor {
    static func process(
        data: Data,
        connectedDisplays: [DisplayMatchCandidate]
    ) -> ConfigImportProcessingResult {
        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            return .decodeFailed(error.localizedDescription)
        }

        let normalized = normalizeForImport(
            sites: config.sites, connectedDisplays: connectedDisplays)
        guard normalized.blockingIssues.isEmpty else {
            return .blocked(config, normalized.blockingIssues)
        }

        let resultConfig = Config(
            showGuideWindow: config.showGuideWindow,
            launchAtLogin: config.launchAtLogin,
            optionShortcutsEnabled: config.optionShortcutsEnabled,
            statusBarIcon: config.statusBarIcon,
            sites: normalized.sites)
        return .success(
            ProcessedConfigImport(
                config: resultConfig,
                fixes: normalized.fixes,
                warnings: normalized.warnings))
    }
}
