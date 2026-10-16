import Foundation

/// 탭 칸(Launchers·Apps)을 트랙패드 두 손가락 가로 스와이프로 넘기는 규칙. 순수 로직이라 테스트로 고정한다.
/// - 한 번 밀면 한 칸만: 제스처 하나(began~ended)에서 문턱을 넘는 순간 한 번만 넘기고, 손을 뗀 뒤의
///   관성(momentum)은 무시한다.
/// - 가로가 세로보다 확실히 클 때만 반응해 세로 스크롤(선반 목록)과 섞이지 않는다.
/// - 방향은 손가락 기준이다: 왼쪽으로 밀면 다음 탭, 오른쪽이면 이전 탭(페이지 넘기기처럼).
public struct TabSwipeTracker: Sendable {
    public enum Phase: Sendable {
        case began, changed, ended, momentum, other
    }

    /// 넘기기 문턱(손가락 이동 pt).
    public static let threshold: Double = 24
    /// 가로가 세로의 이 배수보다 커야 가로 스와이프로 본다.
    public static let dominance: Double = 1.5

    private var accumulated: Double = 0
    private var fired = false

    public init() {}

    /// 스크롤 이벤트 하나를 먹인다. 넘겨야 하면 +1(다음)·-1(이전), 아니면 nil.
    /// - Parameter fingerDX: 손가락 가로 이동(오른쪽 +). `TabSwipeTracker.fingerDX`로 바꿔 넣는다.
    public mutating func step(phase: Phase, fingerDX: Double, deltaY: Double) -> Int? {
        switch phase {
        case .began:
            accumulated = 0
            fired = false
            return consume(fingerDX: fingerDX, deltaY: deltaY)
        case .changed:
            return consume(fingerDX: fingerDX, deltaY: deltaY)
        case .ended, .other:
            accumulated = 0
            fired = false
            return nil
        case .momentum:
            return nil
        }
    }

    /// 이 이벤트를 탭 칸이 삼킬지(가로가 주된 제스처 중이면 삼켜 다른 곳으로 새지 않게 한다).
    public static func isHorizontal(deltaX: Double, deltaY: Double) -> Bool {
        abs(deltaX) > abs(deltaY) * dominance
    }

    /// 시스템 스크롤 값을 손가락 방향으로 바꾼다. 자연스러운 스크롤(방향 반전)이면 값이 손가락을 따른다.
    public static func fingerDX(scrollingDeltaX: Double, directionInverted: Bool) -> Double {
        directionInverted ? scrollingDeltaX : -scrollingDeltaX
    }

    private mutating func consume(fingerDX: Double, deltaY: Double) -> Int? {
        guard !fired, Self.isHorizontal(deltaX: fingerDX, deltaY: deltaY) else { return nil }
        accumulated += fingerDX
        guard abs(accumulated) >= Self.threshold else { return nil }
        fired = true
        // 손가락이 왼쪽(-)이면 다음 탭.
        return accumulated < 0 ? 1 : -1
    }
}

/// 탭 순서에서 한 칸 옮긴 탭. 끝에서 더 가면 nil(넘기지 않고 살짝 튕긴다).
public enum TabStepPolicy {
    public static func target(ids: [String], current: String, step: Int) -> String? {
        guard let index = ids.firstIndex(of: current) else { return ids.first }
        let next = index + step
        return ids.indices.contains(next) ? ids[next] : nil
    }

    /// 제목 줄 빈 자리를 눌렀을 때 갈 탭: 다음 탭, 마지막이면 이전 탭(두 탭이면 늘 다른 쪽).
    public static func neighbor(ids: [String], current: String) -> String? {
        target(ids: ids, current: current, step: 1) ?? target(ids: ids, current: current, step: -1)
    }
}
