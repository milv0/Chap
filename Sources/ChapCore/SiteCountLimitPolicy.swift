import Foundation

/// launch type별 사이트 개수 상한 정책.
///
/// Chap은 하나의 launch type에 몰리는 목록을 4개로 묶어 노치 위젯 칸과
/// 상태바 메뉴 섹션을 예측 가능한 길이로 유지한다. 타입마다 독립적으로
/// 세므로 URL 4개 + App 4개처럼 다른 타입은 각자의 한도를 그대로 쓴다.
public enum SiteCountLimitPolicy {
    public static let maxPerLaunchType = 4

    /// 해당 타입 개수를 센다.
    public static func count(of launchType: LaunchType, in sites: [Site]) -> Int {
        sites.filter { $0.launchType == launchType }.count
    }

    /// 한도 미달이면 추가 가능.
    public static func canAdd(_ launchType: LaunchType, to sites: [Site]) -> Bool {
        count(of: launchType, in: sites) < maxPerLaunchType
    }

    /// 더 추가할 수 있는 개수 (0 이상).
    public static func remainingSlots(for launchType: LaunchType, in sites: [Site]) -> Int {
        max(0, maxPerLaunchType - count(of: launchType, in: sites))
    }
}
