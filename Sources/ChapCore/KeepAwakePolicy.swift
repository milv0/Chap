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

    /// 메뉴 항목 제목. 활성 세션이면 남은 시간을 덧붙인다.
    static func menuTitle(sessionEnd: Date?, now: Date) -> String {
        guard let sessionEnd, sessionEnd > now else { return "Keep Mac Awake" }
        return "Keep Mac Awake — \(remainingLabel(until: sessionEnd, now: now)) left"
    }
}
