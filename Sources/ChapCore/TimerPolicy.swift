import Foundation

/// 노치·메뉴 타이머의 길이, 표시, 진행 규칙 (순수 로직).
///
/// 한 번에 하나만 돌고, 상태는 메모리에만 있다(config에 저장하지 않는다). 끝나는 시각은 벽시계 기준이라
/// 뚜껑을 닫아 잠든 시간도 센다. Keep Awake와는 따로 돈다(화면을 깨워 두지 않는다).
enum TimerPolicy {
    /// 노치 다이얼의 한 눈금. Focus 다이얼과 같은 12칸이라 5분 × 12 = 1시간이 끝이다.
    static let step: TimeInterval = 5 * 60
    static let lengthRange: ClosedRange<TimeInterval> = (5 * 60)...(60 * 60)
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

    // MARK: - Focus 다이얼의 Timer 모드 (노치)

    /// 다이얼 가운데 숫자 아래의 짧은 말.
    static let dialStartLabel = "Start"
    static let dialStopLabel = "Stop"
    /// 다이얼 오른쪽 끝 눈금 글자.
    static let dialMaxLabel = "60m"

    /// 다이얼 위 비율(0…1). 0분이 호의 왼쪽 끝, 60분이 오른쪽 끝이라 돌고 있는 동안
    /// 남은 시간이 같은 눈금 위에서 줄어든다.
    static func dialFraction(length: TimeInterval) -> Double {
        min(max(length / lengthRange.upperBound, 0), 1)
    }

    /// 호 위 비율을 길이로. 5분 눈금에 붙이고 5~60분 안에 둔다.
    static func dialLength(fraction: Double) -> TimeInterval {
        let steps = (fraction * lengthRange.upperBound / step).rounded()
        return min(max(steps * step, lengthRange.lowerBound), lengthRange.upperBound)
    }

    /// 다이얼 가운데에 보이는 고른 길이. "25m".
    static func dialLabel(length: TimeInterval) -> String {
        "\(Int((length / 60).rounded()))m"
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
