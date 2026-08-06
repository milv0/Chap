import Foundation

// MARK: - Validation Types

/// 검증 대상 필드.
public enum ValidationField: String, Sendable {
    case name
    case url
    case appPath
    case folderPath
    case script
    case shortcut
    case windowSizePreset
    case width
    case height
}

/// 검증 이슈 심각도.
public enum ValidationSeverity: Sendable {
    /// 설정을 저장/적용할 수 없는 차단 문제.
    case error
    /// 동작은 하지만 의도치 않은 결과를 낳을 수 있는 문제.
    case warning
}

/// 단일 검증 이슈. UI에서 사이트 인덱스와 메시지를 직접 표시할 수 있다.
public struct ValidationIssue: Sendable {
    public let siteIndex: Int
    public let field: ValidationField
    public let severity: ValidationSeverity
    public let message: String

    public init(
        siteIndex: Int, field: ValidationField, severity: ValidationSeverity, message: String
    ) {
        self.siteIndex = siteIndex
        self.field = field
        self.severity = severity
        self.message = message
    }
}

/// 전체 Config 검증 결과.
public struct ValidationResult: Sendable {
    public let issues: [ValidationIssue]

    /// error 수준 이슈가 없으면 valid.
    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    public var errors: [ValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [ValidationIssue] {
        issues.filter { $0.severity == .warning }
    }
}

// MARK: - Config Validation

/// Config 전체를 검증한다. 반환된 ValidationResult에서 이슈 목록과 유효성을 확인할 수 있다.
///
/// 규칙:
/// - 필수값: name(비어있거나 placeholder면 error), launchType별 필수 필드
/// - URL: http:// 또는 https:// scheme과 host가 모두 있어야 함
/// - 중복(error): shortcut(case-insensitive), url(url타입), appPath(app타입), folderPath(finder타입)
/// - preset: windowSizePreset이 설정됐으면 알려진 값이어야 함
/// - size: width·height 최소 100
/// - displaySizeOverrides: 각 override의 preset·width·height도 동일하게 검증
public func validateConfig(_ config: Config) -> ValidationResult {
    var issues: [ValidationIssue] = []

    // Per-site validation
    for (index, site) in config.sites.enumerated() {
        // Name validation
        let trimmedName = site.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .name, severity: .error,
                    message: "Site name is required."))
        } else if trimmedName == Defaults.newSiteName {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .name, severity: .error,
                    message: "Site name must be changed from the default placeholder."))
        }

        // Launch-type specific required fields
        switch site.launchType {
        case .url:
            let url = site.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if url.isEmpty {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .url, severity: .error,
                        message: "URL is required for URL launch type."))
            } else if !isValidLaunchURL(url) {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .url, severity: .error,
                        message: "URL must use http:// or https:// and include a host."))
            }

        case .app:
            let path = site.appPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if path.isEmpty {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .appPath, severity: .error,
                        message: "Application path is required for App launch type."))
            }

        case .finder:
            let path = site.folderPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if path.isEmpty {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .folderPath, severity: .error,
                        message: "Folder path is required for Finder launch type."))
            }

        case .shell:
            let script = site.script?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if script.isEmpty {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .script, severity: .error,
                        message: "Script is required for Shell launch type."))
            }
        }

        // Window size preset validation
        if let presetID = site.windowSizePreset,
            WindowSizePresets.preset(withID: presetID) == nil
        {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .windowSizePreset, severity: .error,
                    message: "Unknown window size preset '\(presetID)'."))
        }

        // Size validation
        if site.width < 100 {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .width, severity: .error,
                    message: "Width must be at least 100."))
        }
        if site.height < 100 {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .height, severity: .error,
                    message: "Height must be at least 100."))
        }

        for override in site.displaySizeOverrides {
            if let presetID = override.windowSizePreset,
                WindowSizePresets.preset(withID: presetID) == nil
            {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .windowSizePreset, severity: .error,
                        message: "Unknown display size preset '\(presetID)'."))
            }
            if override.width < 100 {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .width, severity: .error,
                        message: "Display override width must be at least 100."))
            }
            if override.height < 100 {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .height, severity: .error,
                        message: "Display override height must be at least 100."))
            }
        }
    }

    // Cross-site duplicate detection
    issues.append(contentsOf: detectDuplicateShortcuts(in: config.sites))
    issues.append(contentsOf: detectDuplicateValues(in: config.sites))

    return ValidationResult(issues: issues)
}

// MARK: - Private Helpers

/// 중복 shortcut 감지(대소문자 무시). 두 번째 이후 출현을 error로 보고.
private func detectDuplicateShortcuts(in sites: [Site]) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    var seen: [String: Int] = [:]  // uppercased key → first index

    for (index, site) in sites.enumerated() {
        guard let shortcut = site.shortcut,
            !shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { continue }

        let trimmed = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count != 1 {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .shortcut, severity: .error,
                    message: "Shortcut must be exactly one character."))
            continue
        }

        // 예약키(".", ",")는 메뉴/설정 전역 단축키와 충돌하므로 거부.
        if reservedShortcutKeys.contains(trimmed) {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .shortcut, severity: .error,
                    message: "Shortcut '\(shortcut)' is reserved and cannot be used."))
            continue
        }

        let key = trimmed.uppercased()
        if let firstIndex = seen[key] {
            issues.append(
                ValidationIssue(
                    siteIndex: index, field: .shortcut, severity: .error,
                    message:
                        "Shortcut '\(shortcut)' is already used by site at index \(firstIndex)."))
        } else {
            seen[key] = index
        }
    }
    return issues
}

/// 중복 url/appPath/folderPath 감지. 같은 launchType끼리만 비교.
private func detectDuplicateValues(in sites: [Site]) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []

    var seenURLs: [String: Int] = [:]
    var seenAppPaths: [String: Int] = [:]
    var seenFolderPaths: [String: Int] = [:]

    for (index, site) in sites.enumerated() {
        switch site.launchType {
        case .url:
            let value = site.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if let firstIndex = seenURLs[value] {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .url, severity: .error,
                        message: "URL '\(value)' is already used by site at index \(firstIndex)."))
            } else {
                seenURLs[value] = index
            }

        case .app:
            let value = (site.appPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if let firstIndex = seenAppPaths[value] {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .appPath, severity: .error,
                        message:
                            "App path '\(value)' is already used by site at index \(firstIndex)."))
            } else {
                seenAppPaths[value] = index
            }

        case .finder:
            let value = (site.folderPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if let firstIndex = seenFolderPaths[value] {
                issues.append(
                    ValidationIssue(
                        siteIndex: index, field: .folderPath, severity: .error,
                        message:
                            "Folder path '\(value)' is already used by site at index \(firstIndex)."
                    ))
            } else {
                seenFolderPaths[value] = index
            }

        case .shell:
            break
        }
    }

    return issues
}
