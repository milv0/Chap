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

    /// 만료 시각 이후로 이만큼 늦게 확인되면 잠든 사이 끝난 세션으로 본다.
    static let lateExpiryTolerance: TimeInterval = 5

    /// 세션이 벽시계 기준으로 끝났는지. 잠든(뚜껑 닫힘) 동안 흐른 시간도 포함한다.
    static func isExpired(sessionEnd: Date?, now: Date) -> Bool {
        guard let sessionEnd else { return false }
        return sessionEnd <= now
    }

    /// 만료가 예정 시각보다 한참 늦게 확인됐는지. 잠자기에서 깨어난 뒤 정리되는
    /// 세션은 사운드·HUD 없이 조용히 끝내기 위해 쓴다.
    static func isLateExpiry(sessionEnd: Date, now: Date) -> Bool {
        now.timeIntervalSince(sessionEnd) > lateExpiryTolerance
    }

    /// 세션 시작 HUD 문구.
    static func hudMessage(startedPresetTitle title: String) -> String {
        "Keep Awake · \(title)"
    }

    /// 세션 종료(수동 해제·만료) HUD 문구.
    static let hudMessageEnded = "Keep Awake Off"

    /// 모든 Quit 확인창에 사용하는 간결한 본문.
    static let quitConfirmationInfo = "Are you sure you want to quit Chap?"

    // MARK: - Focus 위젯 (노치)

    /// 노치 Focus 위젯의 빠른 선택지. 메뉴 프리셋 중 자주 쓰는 셋.
    static let focusPresets: [Preset] = [presets[1], presets[2], presets[3]]

    /// 버튼에 들어갈 짧은 이름 ("1h", "4h", "8h").
    static func shortTitle(of preset: Preset) -> String {
        let hours = Int(preset.duration / 3600)
        return hours > 0 ? "\(hours)h" : "\(Int(preset.duration / 60))m"
    }

    /// 꺼져 있을 때의 한 줄. 번개처럼 바로 켜진다는 느낌.
    static let focusIdleLine = "Stay charged"
    /// 꺼져 있을 때의 보조 문구.
    static let focusIdleHint = "No sleep, no dimming."

    /// 켜져 있을 때 남은 시간에 따라 바뀌는 한 줄. 끝으로 갈수록 톤이 가벼워진다.
    static func focusActiveLine(remaining: TimeInterval) -> String {
        switch remaining {
        case ..<(5 * 60): return "Landing soon"
        case ..<(30 * 60): return "Final stretch"
        case ..<(2 * 3600): return "In the zone"
        default: return "Fully charged"
        }
    }
}
