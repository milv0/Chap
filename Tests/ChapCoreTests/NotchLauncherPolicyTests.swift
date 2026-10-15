import CoreGraphics
import Testing

@testable import Chap

@Suite("NotchLauncherPolicy")
struct NotchLauncherPolicyTests {
    @Test("a positive top inset means the screen has a notch")
    func positiveTopInsetIsNotch() {
        #expect(NotchLauncherPolicy.hasNotch(topSafeAreaInset: 32))
    }

    @Test("a zero top inset means no notch")
    func zeroTopInsetIsNotNotch() {
        #expect(NotchLauncherPolicy.hasNotch(topSafeAreaInset: 0) == false)
    }

    @Test("the toggle alone decides whether the dock is presented")
    func toggleDecidesPresentation() {
        // 노치가 없는 Mac도 켜면 쓸 수 있다 (보이지 않는 hover 구역으로 연다).
        #expect(NotchLauncherPolicy.shouldPresent(enabled: true))
        #expect(NotchLauncherPolicy.shouldPresent(enabled: false) == false)
    }

    @Test("the black strip is the notch on a notched screen and the menu bar without one")
    func stripInsetFollowsHardware() {
        #expect(NotchLauncherPolicy.stripInset(topSafeAreaInset: 38, menuBarHeight: 24) == 38)
        #expect(NotchLauncherPolicy.stripInset(topSafeAreaInset: 0, menuBarHeight: 24) == 24)
        // 메뉴 막대 높이를 못 읽으면 24pt로 둔다 (띠가 0pt로 사라지지 않게).
        #expect(NotchLauncherPolicy.stripInset(topSafeAreaInset: 0, menuBarHeight: 0) == 24)
    }

    @Test("the hover zone sits at the top center, the width of a notch")
    func hoverZoneIsTopCenter() {
        let zone = NotchLauncherPolicy.hoverZone(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), stripInset: 24)
        #expect(zone == CGRect(x: 656, y: 958, width: 200, height: 24))
        #expect(zone.maxY == 982)
        #expect(zone.width == NotchLauncherPolicy.syntheticNotchWidth)
    }

    @Test("the panel wraps the notch by reaching the screen top")
    func panelWrapsNotchToScreenTop() {
        let frame = NotchLauncherPolicy.panelFrame(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            topSafeAreaInset: 32,
            contentSize: CGSize(width: 320, height: 240))

        #expect(frame.midX == 756)
        #expect(frame.maxY == 982)
        #expect(frame.size == CGSize(width: 320, height: 272))
    }

    @Test("the panel frame respects a non-zero screen origin")
    func panelFrameRespectsScreenOrigin() {
        let frame = NotchLauncherPolicy.panelFrame(
            screenFrame: CGRect(x: -1512, y: 200, width: 1512, height: 982),
            topSafeAreaInset: 32,
            contentSize: CGSize(width: 300, height: 100))

        #expect(frame.midX == -756)
        #expect(frame.maxY == 1182)
        #expect(frame.height == 132)
    }

    @Test("the drop badge is a 34pt body with the flare outside it")
    func dropBadgeBodyWithFlare() {
        let frame = NotchLauncherPolicy.dropBadgeFrame(
            notchRect: CGRect(x: 656, y: 950, width: 200, height: 32))

        // 856(노치 오른쪽 끝) 기준: 겹침 18 + 본체 34 + 플레어 6.
        #expect(frame.minX == 856 - NotchLauncherPolicy.dropBadgeNotchOverlap)
        #expect(frame.maxX == 896)
        #expect(frame.minY == 950)
        #expect(frame.height == 32)
    }

    @Test("the drop badge shows only when files exist")
    func dropBadgeVisibility() {
        #expect(NotchLauncherPolicy.shouldShowDropBadge(fileCount: 1))
        #expect(NotchLauncherPolicy.shouldShowDropBadge(fileCount: 0) == false)
    }

    @Test("Glass corner bridges touch both top vertices")
    func glassCornerBridgesTouchTopVertices() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 180)

        let bounds = GlassCornerBridgeShape(radius: 10).path(in: rect).boundingRect

        #expect(bounds.minX == rect.minX)
        #expect(bounds.maxX == rect.maxX)
        #expect(bounds.minY == rect.minY)
        #expect(bounds.maxY == 10)
    }
    @Test("Glass strip leaves outer corners to the Glass bridge")
    func glassStripHasNoBlackAtOuterCorners() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 180)
        let glassStrip = PressedStripShape(
            plateauHalfWidth: 100, centerDepth: 32, edgeDepth: 0
        ).path(in: rect)

        // 외곽은 깊이 0이라 Glass bridge가 보이고, 중앙 plateau는 검정 유지.
        #expect(glassStrip.contains(CGPoint(x: 1, y: 1)) == false)
        #expect(glassStrip.contains(CGPoint(x: rect.midX, y: 31)))
    }
    @Test("Drop feedback builds a panel even with no widget slots")
    func dropFeedbackAllowsEmptyPanel() {
        #expect(NotchLauncherPolicy.shouldBuildPanel(hasSlots: false, forDrop: true))
        #expect(NotchLauncherPolicy.shouldBuildPanel(hasSlots: false, forDrop: false) == false)
        #expect(NotchLauncherPolicy.shouldBuildPanel(hasSlots: true, forDrop: false))
    }
}

@Suite("NotchLauncherPolicy – strip leading content")
struct NotchStripLeadingTests {
    @Test("the seal always rests on the strip, even beside the Focus slot")
    func sealAlways() {
        #expect(NotchLauncherPolicy.stripLeading() == .mascot)
    }
}
