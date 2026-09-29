import Foundation

/// launch type별 사이트 개수 상한 정책.
///
/// 노치 위젯 칸과 상태바 메뉴 섹션을 예측 가능한 길이로 유지하도록 타입마다
/// 상한을 둔다. URL·Finder는 목록 4줄, App은 노치에서 2열 아이콘 격자라
/// 2×3 = 6개까지 허용한다. 타입마다 독립적으로 센다.
public enum SiteCountLimitPolicy {
    /// 목록으로 보이는 타입(URL·Finder)의 상한.
    public static let maxPerListType = 4
    /// 노치 아이콘 격자로 보이는 App의 상한 (2열 × 3줄).
    public static let maxApps = 6

    public static func limit(for launchType: LaunchType) -> Int {
        switch launchType {
        case .app: return maxApps
        case .url, .finder: return maxPerListType
        }
    }

    /// 해당 타입 개수를 센다.
    public static func count(of launchType: LaunchType, in sites: [Site]) -> Int {
        sites.filter { $0.launchType == launchType }.count
    }

    /// 한도 미달이면 추가 가능.
    public static func canAdd(_ launchType: LaunchType, to sites: [Site]) -> Bool {
        count(of: launchType, in: sites) < limit(for: launchType)
    }

    /// 더 추가할 수 있는 개수 (0 이상).
    public static func remainingSlots(for launchType: LaunchType, in sites: [Site]) -> Int {
        max(0, limit(for: launchType) - count(of: launchType, in: sites))
    }
}
