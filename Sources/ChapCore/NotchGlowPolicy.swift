import Foundation

/// 노치 빛이 한 번 빛나는 순간. 순간마다 길이와 굵기가 다르다. 노치는 계속 켜 두지 않고 이 순간에만 빛난다.
public enum NotchGlowMoment: Equatable, Sendable {
    /// 설정에서 켜거나 색을 바꿀 때 미리 보기.
    case preview
    /// Keep Awake나 Timer가 시작됐다.
    case started
    /// Keep Awake가 끝났거나 Timer를 멈췄다. 시작보다 짧고 가늘다.
    case ended
    /// Timer가 다 됐다. 가장 밝고 길다.
    case timerFinished
    /// 새 스크린샷·다운로드·Drop 파일이 들어왔다.
    case arrival
    /// 런처 창이 제자리에 맞춰졌거나 Layout 복원이 끝났다. 가장 짧다.
    case snap

    /// 보이는 시간(초).
    public var duration: Double {
        switch self {
        case .preview, .started: return 1.8
        case .ended: return 1.4
        case .timerFinished: return 2.6
        case .arrival: return 1.6
        case .snap: return 1.1
        }
    }

    /// 가장 안쪽 띠 두께(pt).
    public var lineWidth: Double {
        switch self {
        case .preview, .started, .arrival: return 4
        case .ended, .snap: return 3.5
        case .timerFinished: return 5.5
        }
    }
}

public enum NotchGlowPolicy {
    /// 방금 본 가장 새 파일이 "새로 들어온 것"인지. 처음 본 값(`previous` nil)은 아니다.
    /// 오래된 파일이 늦게 옮겨져 들어온 경우(시각이 `freshness`보다 오래됨)도 아니다.
    public static func isNewArrival(
        previous: Date?, newest: Date?, now: Date, freshness: TimeInterval = 120
    ) -> Bool {
        guard let previous, let newest, newest > previous else { return false }
        return now.timeIntervalSince(newest) <= freshness
    }
}
