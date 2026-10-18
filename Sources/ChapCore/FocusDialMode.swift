import Foundation

/// 노치 Keep Awake 칸 다이얼이 지금 맞추는 것. 같은 다이얼로 Keep Awake(1~12시간)와
/// 타이머(5~60분)를 고른다 (순수 로직). 2.17까지 이 모드의 이름은 Focus였다.
enum FocusDialMode: String, CaseIterable {
    /// 저장 문자열은 예전 이름 그대로 "focus"다(UserDefaults에 남은 값을 그대로 읽는다).
    case keepAwake = "focus"
    case timer

    /// 마지막으로 고른 모드를 기억하는 UserDefaults 키.
    static let storageKey = "ChapFocusDialMode"

    /// 칸을 열 때 보일 모드. 하나만 돌고 있으면 그쪽, 아니면 마지막으로 고른 모드.
    static func initial(stored: String?, isAwakeRunning: Bool, isTimerRunning: Bool)
        -> FocusDialMode
    {
        if isAwakeRunning != isTimerRunning { return isAwakeRunning ? .keepAwake : .timer }
        return stored.flatMap(FocusDialMode.init(rawValue:)) ?? .keepAwake
    }

    var title: String {
        switch self {
        case .keepAwake: return "Keep Awake"
        case .timer: return "Timer"
        }
    }

    var symbol: String {
        switch self {
        case .keepAwake: return "bolt.fill"
        case .timer: return "timer"
        }
    }
}
