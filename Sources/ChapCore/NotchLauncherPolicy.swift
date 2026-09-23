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

    /// 노치 바로 아래에 가로 중앙 정렬로 패널을 놓는다.
    /// 좌표는 AppKit 기준(원점 좌하단)이며 `screenFrame`의 원점을 보존한다.
    public static func panelFrame(
        screenFrame: CGRect, topSafeAreaInset: CGFloat, panelSize: CGSize
    ) -> CGRect {
        CGRect(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - topSafeAreaInset - panelSize.height,
            width: panelSize.width,
            height: panelSize.height)
    }
}
