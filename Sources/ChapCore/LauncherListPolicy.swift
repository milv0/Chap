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
    /// 노치 한 칸에 보이는 최대 항목 수. 타입 상한과 같아 항상 전부 들어간다
    /// (목록은 4줄, Apps 아이콘 격자는 2열 × 3줄).
    public static func maxEntriesPerNotchSlot(for launchType: LaunchType) -> Int {
        SiteCountLimitPolicy.limit(for: launchType)
    }

    /// 목록 칸 폭 범위. 내용이 짧으면 좁히고 길면 자르되, 너무 좁거나 넓어지지 않게 한다.
    public static let listColumnWidthRange: ClosedRange<Double> = 112...170

    /// 가장 긴 줄의 폭(여백 포함)으로 목록 칸 폭을 정한다.
    public static func listColumnWidth(contentWidth: Double) -> Double {
        min(
            max(contentWidth.rounded(.up), listColumnWidthRange.lowerBound),
            listColumnWidthRange.upperBound)
    }

    /// 노치 Apps 칸의 아이콘 격자 열 수. 최대 6개가 2열 × 3줄로 한 칸에 들어간다.
    public static let appIconColumns = 2

    /// 앱 개수에 필요한 격자 줄 수. 빈 줄 공간은 만들지 않는다 (예: 3개 → 2줄).
    public static func appIconRows(forCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (min(count, SiteCountLimitPolicy.maxApps) + appIconColumns - 1) / appIconColumns
    }

    /// 단축키 표기 (예: "⌥S"). 단축키가 없으면 nil.
    public static func shortcutBadge(for site: Site) -> String? {
        guard let key = site.shortcut?.trimmingCharacters(in: .whitespaces), !key.isEmpty
        else { return nil }
        return "⌥\(key.uppercased())"
    }

    /// 앱 아이콘 배지용 키 글자만 (예: "N"). ⌥는 Apps 제목 옆에 한 번만 보여준다.
    public static func shortcutKey(for site: Site) -> String? {
        guard let key = site.shortcut?.trimmingCharacters(in: .whitespaces), !key.isEmpty
        else { return nil }
        return key.uppercased()
    }

    /// 칸 안에 단축키가 있는 항목이 하나라도 있는지. Apps 제목 옆 ⌥ 표시 여부에 쓴다.
    public static func hasShortcut(in section: LauncherListSection) -> Bool {
        section.entries.contains { shortcutKey(for: $0.site) != nil }
    }

    /// 노치에서 눌렀을 때 창 크기·위치를 맞출지. 노치는 확장 런처라서 단축키를 지정하지 않은
    /// 앱은 크기 조정 없이 그냥 연다. 단축키가 있는 앱과 URL·Finder는 항상 맞춘다.
    /// 상태바 메뉴와 ⌥ 단축키 실행은 이 정책과 무관하게 항상 맞춘다.
    public static func resizesOnNotchLaunch(_ site: Site) -> Bool {
        guard site.launchType == .app else { return true }
        return shortcutKey(for: site) != nil
    }

    /// VoiceOver용 실행 버튼 이름 (예: "Launch Slack, Option S").
    public static func launchAccessibilityLabel(for site: Site) -> String {
        guard let key = site.shortcut?.trimmingCharacters(in: .whitespaces), !key.isEmpty
        else { return "Launch \(site.name)" }
        return "Launch \(site.name), Option \(key.uppercased())"
    }

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
        // URL은 Chrome --app 창으로 열린다: 창 모양 아이콘. 번개는 Focus(Keep Awake) 전용이다.
        case .url: return "macwindow"
        case .app: return "app.fill"
        case .finder: return "folder.fill"
        }
    }
}
