import Foundation

/// 목록에 표시할 사이트 하나. `siteIndex`는 `config.sites`의 원본 인덱스이므로
/// 그룹핑 후에도 실행 대상을 정확히 가리킨다.
public struct LauncherListEntry: Equatable {
    public let siteIndex: Int
    public let site: Site

    public init(siteIndex: Int, site: Site) {
        self.siteIndex = siteIndex
        self.site = site
    }
}

/// 같은 launch type 사이트들의 묶음. 메뉴에서는 구분선 단위가 된다.
public struct LauncherListSection: Equatable {
    public let launchType: LaunchType
    public let entries: [LauncherListEntry]

    public init(launchType: LaunchType, entries: [LauncherListEntry]) {
        self.launchType = launchType
        self.entries = entries
    }
}

/// 런처 목록의 구성 규칙. 상태바 NSMenu와 노치 패널이 같은 목록을 보도록
/// 순서·그룹핑·숨김 처리·아이콘 심볼을 한 곳에서 결정한다.
///
/// 표시에서 숨긴 launch type만 제외하며, `⌥` 단축키는 `config.sites` 기준으로
/// 동작하므로 이 정책의 결과와 무관하게 계속 유효하다.
public enum LauncherListPolicy {
    /// 노치 패널 한 칸에 표시할 최대 항목 수. 사이트 자체가 launch type당
    /// `SiteCountLimitPolicy.maxPerLaunchType`개로 제한되므로 항상 전부 들어간다.
    public static let maxEntriesPerNotchSlot = 4

    /// `LaunchType.allCases` 순서로 섹션을 만들고, 각 섹션 안에서는 저장된 순서를 유지한다.
    public static func sections(
        sites: [Site], hiddenLaunchTypes: Set<LaunchType>
    ) -> [LauncherListSection] {
        LaunchType.allCases.compactMap { launchType in
            guard !hiddenLaunchTypes.contains(launchType) else { return nil }
            let entries = sites.enumerated()
                .filter { $0.element.launchType == launchType }
                .map { LauncherListEntry(siteIndex: $0.offset, site: $0.element) }
            guard !entries.isEmpty else { return nil }
            return LauncherListSection(launchType: launchType, entries: entries)
        }
    }

    /// launch type을 나타내는 SF Symbol 이름.
    public static func symbolName(for launchType: LaunchType) -> String {
        switch launchType {
        case .url: return "bolt.fill"
        case .app: return "app.fill"
        case .finder: return "folder.fill"
        case .shell: return "terminal.fill"
        }
    }
}
