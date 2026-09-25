import Foundation

/// 화면 잠자기 방지(Keep Awake) 세션의 프리셋과 표시 문자열 (순수 로직).
///
/// Amphetamine과 같은 세션 개념이다: 지속시간을 골라 켜고, 만료·수동 해제·앱 종료
/// 시 꺼진다. 상태는 메모리에만 있고 config에 저장하지 않는다 (세션 한정).
enum KeepAwakePolicy {
    struct Preset: Equatable {
        let title: String
        let duration: TimeInterval
    }

    /// 메뉴에 노출되는 지속시간 프리셋 (표시 순서).
    static let presets: [Preset] = [
        Preset(title: "30 Minutes", duration: 30 * 60),
        Preset(title: "1 Hour", duration: 60 * 60),
        Preset(title: "4 Hours", duration: 4 * 60 * 60),
        Preset(title: "8 Hours", duration: 8 * 60 * 60),
        Preset(title: "12 Hours", duration: 12 * 60 * 60),
    ]

    /// 남은 시간 표시. 분 단위 올림: "45m", "1h", "4h 2m". 만료·과거면 "0m".
    static func remainingLabel(until end: Date, now: Date) -> String {
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return "0m" }
        let totalMinutes = Int((remaining / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    /// 시계형 남은 시간. 항상 "h:mm:ss" 형식을 벗어나지 않는다:
    /// "0:45:00", "1:07:05", "12:00:00". 만료·과거면 "0:00:00".
    /// 부분 초는 올림해 세션이 실제보다 먼저 0으로 보이지 않게 한다.
    static func remainingClockLabel(until end: Date, now: Date) -> String {
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return "0:00:00" }
        let totalSeconds = Int(remaining.rounded(.up))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    /// 메뉴 항목 제목. 활성 세션이면 남은 시간을 덧붙인다.
    static func menuTitle(sessionEnd: Date?, now: Date) -> String {
        guard let sessionEnd, sessionEnd > now else { return "Keep Mac Awake" }
        return "Keep Mac Awake — \(remainingLabel(until: sessionEnd, now: now)) left"
    }

    /// 세션 시작 HUD 문구.
    static func hudMessage(startedPresetTitle title: String) -> String {
        "Keep Awake · \(title)"
    }

    /// 세션 종료(수동 해제·만료) HUD 문구.
    static let hudMessageEnded = "Keep Awake Off"

    /// 모든 Quit 확인창에 사용하는 간결한 본문.
    static let quitConfirmationInfo = "Are you sure you want to quit Chap?"
}
