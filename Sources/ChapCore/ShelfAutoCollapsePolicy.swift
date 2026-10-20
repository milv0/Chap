import Foundation

/// 비어 있는 선반을 저절로 접는 규칙. 저절로 접힌 상태는 저장하지 않는다(파일이 생기면 바로 펼쳐진다).
public enum ShelfAutoCollapsePolicy {
    /// 스크린샷이 하나도 없으면 Screenshots 칸을 검정 띠 왼쪽 아이콘으로 접는다.
    public static func collapsesScreenshots(count: Int) -> Bool {
        count == 0
    }

    /// 접어 둔 선반(Screenshots·Downloads)을 저절로 펼치는 시간: 가장 새 파일이 이만큼 안이면 펼친다.
    public static let recentShelfWindow: TimeInterval = 10 * 60

    /// 사용자가 접어 둔 선반을 이번에 열 때 펼칠지. 펼친 상태는 저장하지 않는다(접은 설정은 그대로).
    /// - Parameter newest: 선반 파일 중 가장 새 것의 시각(받은 시각·찍은 시각). 없으면 펼치지 않는다.
    /// - Parameter dismissed: 저절로 펼쳐진 칸을 사용자가 다시 접었을 때의 가장 새 시각. 그보다 새 파일이
    ///   들어올 때까지는 다시 펼치지 않는다(접을 때마다 또 펼쳐지지 않게).
    public static func expandsForRecent(newest: Date?, dismissed: Date?, now: Date) -> Bool {
        guard let newest else { return false }
        if let dismissed, newest <= dismissed { return false }
        let age = now.timeIntervalSince(newest)
        // 시계가 어긋나 미래 시각인 파일은 1분까지만 "방금"으로 본다.
        return age < recentShelfWindow && age > -60
    }
}
