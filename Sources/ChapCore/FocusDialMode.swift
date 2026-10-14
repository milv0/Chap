import Foundation

/// 노치 Focus 칸 다이얼이 지금 맞추는 것. 같은 다이얼로 Keep Mac Awake(1~12시간)와
/// 타이머(5~60분)를 고른다 (순수 로직).
enum FocusDialMode: String, CaseIterable {
    case focus
    case timer

    /// 마지막으로 고른 모드를 기억하는 UserDefaults 키.
    static let storageKey = "ChapFocusDialMode"

    /// 칸을 열 때 보일 모드. 하나만 돌고 있으면 그쪽, 아니면 마지막으로 고른 모드.
    static func initial(stored: String?, isFocusRunning: Bool, isTimerRunning: Bool)
        -> FocusDialMode
    {
        if isFocusRunning != isTimerRunning { return isFocusRunning ? .focus : .timer }
        return stored.flatMap(FocusDialMode.init(rawValue:)) ?? .focus
    }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .timer: return "Timer"
        }
    }

    var symbol: String {
        switch self {
        case .focus: return "bolt.fill"
        case .timer: return "timer"
        }
    }
}
