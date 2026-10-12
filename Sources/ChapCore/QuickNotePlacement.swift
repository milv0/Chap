import CoreGraphics

/// Quick Note 창이 처음 뜨는 자리: 노치 바로 아래, 노치 가운데에 맞춰 붙인다.
/// 좌표는 AppKit 화면 좌표(아래가 0)다. 창이 화면 밖으로 나가지 않게 보이는 영역 안으로 당긴다.
public enum QuickNotePlacement {
    /// - Parameters:
    ///   - windowSize: 창 전체 크기(제목 막대 포함).
    ///   - notchRect: 하드웨어 노치 영역. 창 윗변이 노치 아랫변에 닿는다.
    ///   - visibleFrame: 메뉴 막대·Dock을 뺀 화면 영역.
    public static func origin(windowSize: CGSize, notchRect: CGRect, visibleFrame: CGRect)
        -> CGPoint
    {
        let top = min(notchRect.minY, visibleFrame.maxY)
        let maxX = max(visibleFrame.maxX - windowSize.width, visibleFrame.minX)
        let x = min(max(notchRect.midX - windowSize.width / 2, visibleFrame.minX), maxX)
        let y = max(top - windowSize.height, visibleFrame.minY)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }
}
