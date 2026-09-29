import Foundation

struct ProcessedConfigImport {
    let config: Config
    let fixes: [ImportFix]
    let warnings: [ImportWarning]
}

enum ConfigImportProcessingResult {
    case success(ProcessedConfigImport)
    case blocked(Config, [ImportBlockingIssue])
    /// 2.1에서 제거된 Shell 항목이 들어 있어 가져오기를 거부했다.
    case unsupportedShellSites([String])
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
        // 일부만 조용히 빠진 설정을 적용하지 않도록 원자적으로 거부한다.
        guard config.removedShellSiteNames.isEmpty else {
            return .unsupportedShellSites(config.removedShellSiteNames)
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
            hiddenMenuLaunchTypes: config.hiddenMenuLaunchTypes,
            sites: normalized.sites)
        return .success(
            ProcessedConfigImport(
                config: resultConfig,
                fixes: normalized.fixes,
                warnings: normalized.warnings))
    }
}
