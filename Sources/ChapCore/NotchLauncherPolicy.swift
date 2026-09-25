import CoreGraphics

/// 노치 런처의 표시 조건과 패널 위치를 결정하는 순수 정책.
///
/// AppKit 화면 조회와 분리해 두어 노치 없는 Mac(Air M1, 외장 모니터, Mac mini)
/// 동작을 테스트로 고정할 수 있다.
public enum NotchLauncherPolicy {
    /// 노치 장비 판별. macOS는 노치 높이를 화면 상단 safe area inset으로 보고한다.
    public static func hasNotch(topSafeAreaInset: CGFloat) -> Bool {
        topSafeAreaInset > 0
    }

    /// 사용자가 켰고 노치가 있을 때만 표시한다. 둘 중 하나라도 없으면 상태바 메뉴만 쓴다.
    public static func shouldPresent(enabled: Bool, topSafeAreaInset: CGFloat) -> Bool {
        enabled && hasNotch(topSafeAreaInset: topSafeAreaInset)
    }

    /// 화면 최상단에 붙여 노치를 검정으로 감싼다. 반환 높이는 상단바 구간
    /// (`topSafeAreaInset`)과 콘텐츠 높이의 합이며, 좌표는 AppKit 기준
    /// (원점 좌하단)으로 `screenFrame`의 원점을 보존한다.
    public static func panelFrame(
        screenFrame: CGRect, topSafeAreaInset: CGFloat, contentSize: CGSize
    ) -> CGRect {
        let height = topSafeAreaInset + contentSize.height
        return CGRect(
            x: screenFrame.midX - contentSize.width / 2,
            y: screenFrame.maxY - height,
            width: contentSize.width,
            height: height)
    }

    /// 노치 오른쪽에 붙는 Drop 배지 도커의 프레임. 보이는 본체는
    /// `NotchGeometry.badgeBodyWidth` × 노치 높이이고, 왼쪽 겹침(overlap)은
    /// 노치 밑으로, 오른쪽 플레어는 본체 바깥으로 나가 상단바에 합류한다.
    /// 폭 = 겹침 + 본체 폭 + 플레어.
    public static let dropBadgeNotchOverlap: CGFloat = NotchGeometry.badgeNotchOverlap

    public static func dropBadgeFrame(notchRect: CGRect) -> CGRect {
        CGRect(
            x: notchRect.maxX - dropBadgeNotchOverlap,
            y: notchRect.minY,
            width: dropBadgeNotchOverlap + NotchGeometry.badgeBodyWidth
                + NotchGeometry.dockFlareRadius,
            height: notchRect.height)
    }

    /// 노치 왼쪽에 붙는 Keep Awake 배지 도커의 프레임.
    /// 오른쪽 Drop 배지와 같은 크기로 노치 왼쪽 변에 미러링된다:
    /// 오른쪽 겹침은 노치 밑으로, 왼쪽 플레어는 본체 바깥으로 나간다.
    public static func awakeBadgeFrame(notchRect: CGRect) -> CGRect {
        let width =
            dropBadgeNotchOverlap + NotchGeometry.badgeBodyWidth
            + NotchGeometry.dockFlareRadius
        return CGRect(
            x: notchRect.minX + dropBadgeNotchOverlap - width,
            y: notchRect.minY,
            width: width,
            height: notchRect.height)
    }

    /// Drop 배지는 보관함에 파일이 있을 때만 보인다.
    public static func shouldShowDropBadge(fileCount: Int) -> Bool {
        fileCount > 0
    }
}
