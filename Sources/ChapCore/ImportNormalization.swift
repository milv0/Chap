import Foundation

// MARK: - Import Result Types

public enum ImportWarningKind: Equatable {
    case ambiguousDisplay
    case disconnectedDisplay
}

public struct ImportWarning {
    public let siteIndex: Int
    public let kind: ImportWarningKind
    public let message: String

    public init(siteIndex: Int, kind: ImportWarningKind, message: String) {
        self.siteIndex = siteIndex
        self.kind = kind
        self.message = message
    }
}

public struct ImportFix {
    public let siteIndex: Int
    public let message: String

    public init(siteIndex: Int, message: String) {
        self.siteIndex = siteIndex
        self.message = message
    }
}

public struct ImportBlockingIssue {
    public let siteIndex: Int
    public let field: ValidationField
    public let message: String

    public init(siteIndex: Int, field: ValidationField, message: String) {
        self.siteIndex = siteIndex
        self.field = field
        self.message = message
    }
}

public struct ImportResult {
    public let sites: [Site]
    public let fixes: [ImportFix]
    public let blockingIssues: [ImportBlockingIssue]
    public let warnings: [ImportWarning]
}

// MARK: - Import Normalization

/// 안전한 정규화를 적용한 뒤 전체 Config validation을 실행한다.
/// blocking issue가 하나라도 있으면 호출자는 기존 설정을 변경하면 안 된다.
public func normalizeForImport(
    sites: [Site],
    connectedDisplays: [DisplayMatchCandidate]
) -> ImportResult {
    var normalized = sites
    var fixes: [ImportFix] = []

    for index in normalized.indices {
        if normalized[index].width < 100 {
            normalized[index].width = 100
            fixes.append(ImportFix(siteIndex: index, message: "Width was raised to 100."))
        }
        if normalized[index].height < 100 {
            normalized[index].height = 100
            fixes.append(ImportFix(siteIndex: index, message: "Height was raised to 100."))
        }
        if let presetID = normalized[index].windowSizePreset,
            WindowSizePresets.preset(withID: presetID) == nil
        {
            normalized[index].windowSizePreset = nil
            fixes.append(
                ImportFix(siteIndex: index, message: "Unknown size preset was changed to Custom."))
        }

        for overrideIndex in normalized[index].displaySizeOverrides.indices {
            if normalized[index].displaySizeOverrides[overrideIndex].width < 100 {
                normalized[index].displaySizeOverrides[overrideIndex].width = 100
                fixes.append(
                    ImportFix(
                        siteIndex: index,
                        message: "Display override width was raised to 100."))
            }
            if normalized[index].displaySizeOverrides[overrideIndex].height < 100 {
                normalized[index].displaySizeOverrides[overrideIndex].height = 100
                fixes.append(
                    ImportFix(
                        siteIndex: index,
                        message: "Display override height was raised to 100."))
            }
            if let presetID = normalized[index].displaySizeOverrides[overrideIndex]
                .windowSizePreset,
                WindowSizePresets.preset(withID: presetID) == nil
            {
                normalized[index].displaySizeOverrides[overrideIndex].windowSizePreset = nil
                fixes.append(
                    ImportFix(
                        siteIndex: index,
                        message: "Unknown display override preset was changed to Custom."))
            }
        }
    }

    let beforeMigration = normalized
    let migration = migrateDisplayIdentifiers(
        sites: normalized, connectedDisplays: connectedDisplays)
    normalized = migration.sites
    for index in normalized.indices
    where normalized[index].displayIdentifier != beforeMigration[index].displayIdentifier
        || normalized[index].displayName != beforeMigration[index].displayName
    {
        fixes.append(
            ImportFix(siteIndex: index, message: "Display selection was updated."))
    }

    let beforeShortcuts = normalized
    normalized = sanitizedShortcuts(for: normalized)
    for index in normalized.indices
    where normalized[index].shortcut != beforeShortcuts[index].shortcut {
        fixes.append(
            ImportFix(siteIndex: index, message: "Invalid or duplicate shortcut was removed."))
    }

    let validation = validateConfig(Config(sites: normalized))
    let blockingIssues = validation.errors.map {
        ImportBlockingIssue(siteIndex: $0.siteIndex, field: $0.field, message: $0.message)
    }

    return ImportResult(
        sites: normalized,
        fixes: fixes,
        blockingIssues: blockingIssues,
        warnings: migration.warnings)
}

// MARK: - Display Migration

public struct DisplayMigrationResult {
    public let sites: [Site]
    public let warnings: [ImportWarning]
}

/// UUID가 연결되어 있으면 유지한다. UUID가 없거나 stale이면 이름을 사용하되,
/// 이름이 정확히 하나의 연결 화면과 일치할 때만 UUID를 보강한다.
public func migrateDisplayIdentifiers(
    sites: [Site],
    connectedDisplays: [DisplayMatchCandidate]
) -> DisplayMigrationResult {
    var result = sites
    var warnings: [ImportWarning] = []

    for (index, site) in sites.enumerated() {
        if let identifier = site.displayIdentifier,
            !identifier.isEmpty,
            let connectedDisplay = connectedDisplays.first(where: { $0.identifier == identifier })
        {
            if site.displayName != connectedDisplay.name {
                result[index].displayName = connectedDisplay.name
            }
            continue
        }

        guard let displayName = site.displayName, !displayName.isEmpty else {
            if let identifier = site.displayIdentifier, !identifier.isEmpty {
                warnings.append(
                    ImportWarning(
                        siteIndex: index,
                        kind: .disconnectedDisplay,
                        message: "The selected display is not currently connected."))
            }
            continue
        }

        let matches = connectedDisplays.filter { $0.name == displayName }
        switch matches.count {
        case 0:
            warnings.append(
                ImportWarning(
                    siteIndex: index,
                    kind: .disconnectedDisplay,
                    message: "Display '\(displayName)' is not currently connected."))
        case 1:
            if let identifier = matches[0].identifier, !identifier.isEmpty {
                result[index].displayIdentifier = identifier
            }
        default:
            warnings.append(
                ImportWarning(
                    siteIndex: index,
                    kind: .ambiguousDisplay,
                    message:
                        "Multiple displays named '\(displayName)' are connected. Please reselect one."
                ))
        }
    }

    return DisplayMigrationResult(sites: result, warnings: warnings)
}
