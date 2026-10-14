import Foundation

/// 노치·메뉴 타이머의 길이, 표시, 진행 규칙 (순수 로직).
///
/// 한 번에 하나만 돌고, 상태는 메모리에만 있다(config에 저장하지 않는다). 끝나는 시각은 벽시계 기준이라
/// 뚜껑을 닫아 잠든 시간도 센다. Keep Mac Awake와는 따로 돈다(화면을 깨워 두지 않는다).
enum TimerPolicy {
    /// 노치 칸의 −/+가 한 번에 바꾸는 길이.
    static let step: TimeInterval = 5 * 60
    static let lengthRange: ClosedRange<TimeInterval> = (5 * 60)...(180 * 60)
    static let defaultLength: TimeInterval = 25 * 60
    /// 메뉴에서 바로 고르는 길이.
    static let presets: [TimeInterval] = [5, 10, 15, 25, 30, 45, 60].map { $0 * 60 }

    /// 남은 시간 시계. 1시간 미만은 "m:ss", 넘으면 "h:mm:ss". 부분 초는 올림해 0이 먼저 보이지 않게 한다.
    static func clockLabel(until end: Date, now: Date) -> String {
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return "0:00" }
        let total = Int(remaining.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// 고를 길이(초)의 시계. 시작 전 칸에 "25:00"처럼 보인다.
    static func clockLabel(length: TimeInterval) -> String {
        clockLabel(
            until: Date(timeIntervalSinceReferenceDate: length),
            now: .init(timeIntervalSinceReferenceDate: 0))
    }

    /// −/+ 한 번. 5분 눈금에 맞춘 뒤 한 칸 옮기고 범위 안에 둔다.
    static func stepped(_ length: TimeInterval, by direction: Int) -> TimeInterval {
        let snapped =
            direction > 0
            ? (length / step).rounded(.down) * step
            : (length / step).rounded(.up) * step
        let next = snapped + Double(direction.signum()) * step
        return min(max(next, lengthRange.lowerBound), lengthRange.upperBound)
    }

    /// 저장해 둔 마지막 길이. 범위를 벗어나면 기본 길이.
    static func length(forStored stored: TimeInterval) -> TimeInterval {
        lengthRange.contains(stored) ? stored : defaultLength
    }

    /// 지난 비율(0...1). 노치 칸의 진행선이 쓴다.
    static func progress(end: Date, length: TimeInterval, now: Date) -> Double {
        guard length > 0 else { return 1 }
        let remaining = max(end.timeIntervalSince(now), 0)
        return min(max(1 - remaining / length, 0), 1)
    }

    static func presetTitle(_ length: TimeInterval) -> String {
        let minutes = Int(length / 60)
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 Hour" : "\(hours) Hours"
        }
        return minutes == 1 ? "1 Minute" : "\(minutes) Minutes"
    }

    static func menuTitle(end: Date?, now: Date) -> String {
        guard let end, end > now else { return "Timer" }
        return "Timer — \(clockLabel(until: end, now: now)) left"
    }

    /// 끝났을 때 HUD 문구.
    static let finishedMessage = "Time's up"
}
