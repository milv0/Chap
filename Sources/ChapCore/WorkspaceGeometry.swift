import CoreGraphics

/// 실제 AX bounds와 디스플레이 상대 프레임 사이를 변환한다.
public enum WorkspaceGeometry {
    public typealias Bounds = (left: Int, top: Int, right: Int, bottom: Int)

    /// 현재 AX bounds를 visibleFrame 안의 0...1 비율로 캡처한다.
    public static func capture(
        bounds: Bounds, visibleFrame: CGRect, primaryHeight: CGFloat
    ) -> WorkspaceFrame {
        let visibleTop = primaryHeight - visibleFrame.maxY
        let visibleWidth = max(visibleFrame.width, 1)
        let visibleHeight = max(visibleFrame.height, 1)
        let width = clamp(CGFloat(bounds.right - bounds.left) / visibleWidth)
        let height = clamp(CGFloat(bounds.bottom - bounds.top) / visibleHeight)
        let left = min(
            clamp((CGFloat(bounds.left) - visibleFrame.minX) / visibleWidth),
            max(1 - width, 0))
        let top = min(
            clamp((CGFloat(bounds.top) - visibleTop) / visibleHeight),
            max(1 - height, 0))
        return WorkspaceFrame(
            left: Double(left), top: Double(top), width: Double(width), height: Double(height))
    }

    /// 저장된 비율을 현재 visibleFrame 안의 AX 좌상단 bounds로 복원한다.
    public static func bounds(
        for frame: WorkspaceFrame, visibleFrame: CGRect, primaryHeight: CGFloat
    ) -> Bounds {
        let visibleWidth = max(visibleFrame.width, 100)
        let visibleHeight = max(visibleFrame.height, 100)
        let minimumWidth = min(100 / visibleWidth, 1)
        let minimumHeight = min(100 / visibleHeight, 1)
        let widthRatio = min(max(CGFloat(frame.width), minimumWidth), 1)
        let heightRatio = min(max(CGFloat(frame.height), minimumHeight), 1)
        let leftRatio = min(clamp(CGFloat(frame.left)), max(1 - widthRatio, 0))
        let topRatio = min(clamp(CGFloat(frame.top)), max(1 - heightRatio, 0))
        let width = Int((visibleWidth * widthRatio).rounded())
        let height = Int((visibleHeight * heightRatio).rounded())
        let left = Int((visibleFrame.minX + visibleWidth * leftRatio).rounded())
        let visibleTop = primaryHeight - visibleFrame.maxY
        let top = Int((visibleTop + visibleHeight * topRatio).rounded())
        return (left, top, left + width, top + height)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}
