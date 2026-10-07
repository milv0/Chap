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

    /// 꺼져 있을 때의 한 줄. "chap"은 창이 제자리에 딱 붙는 소리다: 딱 켜고 딱 끈다.
    static let focusIdleLine = "Chap on"
    /// 꺼져 있을 때의 보조 문구.
    static let focusIdleHint = "No sleep, no dimming."
    /// 켜져 있을 때 끄는 버튼.
    static let focusOffTitle = "Chap off"
    /// 다이얼 가운데 숫자 아래의 짧은 말. 숫자가 주인공이라 "Chap" 없이 On/Off만 쓴다.
    static let focusDialOnLabel = "On"
    static let focusDialOffLabel = "Off"

    /// Focus 위젯이 처음 고르고 있는 시간. 마지막으로 켠 시간을 기억하되, 목록에 없으면 이 값.
    static let defaultFocusPreset = focusPresets[0]

    /// 저장된 길이(초)를 Focus 선택지로 되돌린다. 목록에 없거나 없으면 기본값.
    static func focusPreset(forStoredDuration duration: Double) -> Preset {
        focusPresets.first { $0.duration == duration } ?? defaultFocusPreset
    }

    // MARK: - Focus 다이얼

    /// 다이얼로 고를 수 있는 시간(시간 단위). 1시간 간격.
    static let focusDialHours: ClosedRange<Int> = 1...12
    /// 처음 고르고 있는 시간.
    static let defaultFocusDialHours = 1
    /// 다이얼 호가 차지하는 각도. 반원(180°)보다 길고 아래가 평평하게 열린다(아래 120° 빈 곳).
    static let focusDialSweep: Double = 240

    /// 저장된 길이(초)를 다이얼 시간으로. 범위 밖이면 가장 가까운 끝, 값이 없으면 기본값.
    static func focusDialHours(forStoredDuration duration: Double) -> Int {
        guard duration > 0 else { return defaultFocusDialHours }
        let hours = Int((duration / 3600).rounded())
        return min(max(hours, focusDialHours.lowerBound), focusDialHours.upperBound)
    }

    /// 다이얼 위 비율(0…1). 0시간이 호의 왼쪽 끝, 12시간이 오른쪽 끝인 하나의 눈금이라 켜진 뒤에도 남은 시간이
    /// 같은 눈금 위에서 줄어든다(주방 타이머처럼).
    static func focusDialFraction(hours: Double) -> Double {
        min(max(hours / Double(focusDialHours.upperBound), 0), 1)
    }

    /// 다이얼 가운데 기준 점(아래가 +y)을 시간으로. 12시 방향이 호의 가운데, 시계 방향이 늘어나는 쪽이다.
    /// 아래 빈 곳의 점은 가까운 끝으로 붙는다.
    static func focusDialHours(dx: Double, dy: Double) -> Int {
        let angle = atan2(dx, -dy) * 180 / .pi  // -180…180, 0 = 12시
        let half = focusDialSweep / 2
        let clamped = min(max(angle, -half), half)
        let fraction = (clamped + half) / focusDialSweep
        let hours = Int((fraction * Double(focusDialHours.upperBound)).rounded())
        return min(max(hours, focusDialHours.lowerBound), focusDialHours.upperBound)
    }

    /// 다이얼로 고른 시간의 세션. 메뉴 프리셋과 같은 길이면 그 이름을 쓴다.
    static func focusPreset(hours: Int) -> Preset {
        let clamped = min(max(hours, focusDialHours.lowerBound), focusDialHours.upperBound)
        let duration = TimeInterval(clamped * 3600)
        return presets.first { $0.duration == duration }
            ?? Preset(title: "\(clamped) Hours", duration: duration)
    }

    /// 노치 Focus 요청의 길이를 세션으로. 메뉴 프리셋이나 다이얼 시간(1~12시간 정수)만 받는다.
    static func focusPreset(forRequestedDuration duration: TimeInterval) -> Preset? {
        if let preset = presets.first(where: { $0.duration == duration }) { return preset }
        let hours = duration / 3600
        guard hours == hours.rounded(), focusDialHours.contains(Int(hours)) else { return nil }
        return focusPreset(hours: Int(hours))
    }

    /// 세션 길이를 모를 때(앱이 세션 시작 뒤 다시 그려진 경우 등) 남은 시간을 담을 수 있는 가장 짧은 프리셋 길이.
    /// 링이 0이나 1로 튀지 않고 그럴듯한 비율을 보이게 한다.
    static func inferredFocusDuration(remaining: TimeInterval) -> TimeInterval {
        presets.map(\.duration).first { $0 >= remaining } ?? max(remaining, 1)
    }

    /// 남은 비율(1 → 0). 길이를 모르면 nil이라 진행 막대를 그리지 않는다.
    static func focusProgress(remaining: TimeInterval, duration: TimeInterval?) -> Double? {
        guard let duration, duration > 0 else { return nil }
        return min(max(remaining / duration, 0), 1)
    }

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
