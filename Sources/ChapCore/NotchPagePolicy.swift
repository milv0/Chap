import CoreGraphics
import Foundation

/// 노치 도커의 좌·중·우 페이지 규칙. 12칸을 4칸씩 나누고, 위젯이 있는
/// 페이지만 이동 대상으로 삼는다. 뷰와 이벤트 처리에서 분리한 순수 정책이다.
public enum NotchPagePolicy {
    /// 칸 배열을 `NotchWidget.pageSize`칸씩 끊는다. 마지막 페이지가 짧으면 빈 칸으로 채운다.
    public static func pages<T>(_ slots: [T], empty: T) -> [[T]] {
        let size = NotchWidget.pageSize
        return stride(from: 0, to: NotchWidget.slotCount, by: size).map { start in
            (start..<start + size).map { slots.indices.contains($0) ? slots[$0] : empty }
        }
    }

    /// 위젯이 하나라도 있는 페이지 번호 (0부터). 빈 페이지는 점도 이동 대상도 아니다.
    public static func visiblePageIndices(_ widgets: [NotchWidget]) -> [Int] {
        pages(widgets, empty: .none).enumerated()
            .filter { _, page in page.contains { $0 != .none } }
            .map(\.offset)
    }

    /// 보이는 페이지가 둘 이상일 때만 페이지 점을 보여준다.
    public static func showsPageIndicator(visiblePageCount: Int) -> Bool {
        visiblePageCount > 1
    }

    /// 현재 위치에서 `step`만큼 이동한 위치. 양 끝에서 멈추며 순환하지 않는다.
    public static func position(from current: Int, step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(current + step, 0), count - 1)
    }
}

/// 트랙패드 가로 스와이프(스크롤 휠 이벤트)를 페이지 이동 한 번으로 바꾼다.
/// 한 제스처에서 한 번만 넘기고, 세로 스크롤이 우세하면 무시한다.
public struct NotchPageSwipeTracker {
    /// 이 거리(pt)를 넘게 가로로 쓸어야 페이지가 넘어간다.
    public static let threshold: CGFloat = 36

    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var didStepInGesture = false

    public init() {}

    /// 스크롤 이벤트 하나를 누적한다.
    /// - Parameters:
    ///   - deltaX: 가로 스크롤 양. 트랙패드에서 왼쪽으로 쓸면 음수다.
    ///   - deltaY: 세로 스크롤 양.
    ///   - began: 새 제스처의 시작(phase .began, 또는 phase 없는 마우스 휠).
    ///   - ended: 제스처 종료(phase .ended/.cancelled 또는 momentum 종료).
    /// - Returns: 넘길 방향 (+1 다음 페이지, -1 이전 페이지). 넘기지 않으면 nil.
    public mutating func consume(
        deltaX: CGFloat, deltaY: CGFloat, began: Bool, ended: Bool
    ) -> Int? {
        if began { reset() }
        defer { if ended { reset() } }
        accumulatedX += deltaX
        accumulatedY += deltaY
        guard !didStepInGesture,
            abs(accumulatedX) >= Self.threshold,
            abs(accumulatedX) > abs(accumulatedY) * 1.5
        else { return nil }
        didStepInGesture = true
        // 왼쪽으로 쓸면(deltaX < 0) 오른쪽 페이지가 들어온다.
        return accumulatedX < 0 ? 1 : -1
    }

    public mutating func reset() {
        accumulatedX = 0
        accumulatedY = 0
        didStepInGesture = false
    }
}
