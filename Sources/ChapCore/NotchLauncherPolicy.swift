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

    /// 일반 hover는 표시할 슬롯이 있어야 하지만, 파일 드래그는 슬롯이 없어도
    /// Drop here 피드백을 위해 빈 패널을 만들어야 한다.
    public static func shouldBuildPanel(hasSlots: Bool, forDrop: Bool) -> Bool {
        hasSlots || forDrop
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

    /// 펼친 도커의 최소 폭. 위젯이 적어도 노치 양옆 상태 영역(Keep Awake 시계, Drop·Mirror·
    /// Quick Note 아이콘)을 넉넉히 감싸고, 칸이 두세 개뿐일 때 도커가 노치에 붙어 보이지 않게 한다.
    public static let dockMinimumWidth: CGFloat = 640

    /// 노치 폭 기준 최소 도커 폭: 노치 + 양쪽 상태 영역(110pt씩) + 여유, 그리고 `dockMinimumWidth` 중 큰 값.
    public static func dockMinWidth(notchWidth: CGFloat) -> CGFloat {
        max(notchWidth + 2 * NotchGeometry.stripPlateauSideWidth + 80, dockMinimumWidth)
    }

    /// 상단 띠 도구 아이콘(Mirror, Quick Note)의 누름 폭과 간격.
    public static let stripToolPitch: CGFloat = 28

    /// Drop 배지 아이콘 중심의 노치 오른쪽 끝 기준 거리. 배지 본체(34pt)는 노치 밑으로
    /// 12pt 파고든 뒤 시작하고, 아이콘은 본체 가운데에서 왼쪽으로 4pt 광학 보정된다.
    public static let dropBadgeIconCenterOffset: CGFloat = NotchGeometry.badgeBodyWidth / 2 - 4

    /// 상단 띠 도구 아이콘들의 중심 위치(노치 오른쪽 끝 기준). Drop 배지가 있으면 배지 바로
    /// 오른쪽부터, 없으면 배지 자리부터 `stripToolPitch` 간격으로 나란히 둔다.
    public static func stripToolCenterOffsets(besideDropBadge: Bool, count: Int) -> [CGFloat] {
        let first = dropBadgeIconCenterOffset + (besideDropBadge ? stripToolPitch : 0)
        return (0..<max(count, 0)).map { first + CGFloat($0) * stripToolPitch }
    }

    /// 띠 도구 팝업(Mirror 미리보기, Quick Note 카드)의 중심. 아이콘 아래 8pt에 걸고,
    /// 도커 가장자리에서 12pt 안쪽으로 가로 위치를 제한한다.
    public static func stripPopupCenter(
        iconCenterX: CGFloat, popupSize: CGSize, containerWidth: CGFloat, stripHeight: CGFloat
    ) -> CGPoint {
        let halfWidth = popupSize.width / 2
        let x = min(max(iconCenterX, halfWidth + 12), containerWidth - halfWidth - 12)
        return CGPoint(x: x, y: stripHeight + 8 + popupSize.height / 2)
    }

    /// 도커 안 클릭이 열린 띠 팝업을 접어야 하는지. 팝업 안 클릭은 유지하고, 상단 띠 클릭은
    /// 각 아이콘 버튼이 직접 처리하므로 건드리지 않는다 (아이콘으로 다시 열리는 것을 막는다).
    public static func shouldCollapseStripPopup(
        click: CGPoint, popupFrame: CGRect, stripHeight: CGFloat
    ) -> Bool {
        click.y > stripHeight && !popupFrame.contains(click)
    }

    /// Drop 배지는 보관함에 파일이 있을 때만 보인다.
    public static func shouldShowDropBadge(fileCount: Int) -> Bool {
        fileCount > 0
    }
}
