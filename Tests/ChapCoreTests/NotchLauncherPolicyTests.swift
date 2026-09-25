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

    @Test("presentation requires both the toggle and notch hardware")
    func requiresToggleAndHardware() {
        #expect(NotchLauncherPolicy.shouldPresent(enabled: true, topSafeAreaInset: 32))
        #expect(NotchLauncherPolicy.shouldPresent(enabled: false, topSafeAreaInset: 32) == false)
        #expect(NotchLauncherPolicy.shouldPresent(enabled: true, topSafeAreaInset: 0) == false)
        #expect(NotchLauncherPolicy.shouldPresent(enabled: false, topSafeAreaInset: 0) == false)
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

        // 856(노치 오른쪽 끝) 기준: 겹침 12 + 본체 34 + 플레어 10.
        #expect(frame.minX == 856 - NotchLauncherPolicy.dropBadgeNotchOverlap)
        #expect(frame.maxX == 900)
        #expect(frame.minY == 950)
        #expect(frame.height == 32)
    }

    @Test("the drop badge shows only when files exist")
    func dropBadgeVisibility() {
        #expect(NotchLauncherPolicy.shouldShowDropBadge(fileCount: 1))
        #expect(NotchLauncherPolicy.shouldShowDropBadge(fileCount: 0) == false)
    }

    @Test("the awake badge mirrors the drop badge on the notch's left")
    func awakeBadgeMirrorsLeft() {
        let notch = CGRect(x: 656, y: 950, width: 200, height: 32)

        let left = NotchLauncherPolicy.awakeBadgeFrame(notchRect: notch)
        let right = NotchLauncherPolicy.dropBadgeFrame(notchRect: notch)

        // 오른쪽 배지와 같은 크기로, 노치 왼쪽 변 기준 대칭.
        #expect(left.size == right.size)
        #expect(left.maxX == 656 + NotchLauncherPolicy.dropBadgeNotchOverlap)
        #expect(left.minY == 950)

        // 확장 시 노치 쪽 변은 고정된 채 왼쪽으로만 자란다.
        let expanded = NotchLauncherPolicy.awakeBadgeFrame(notchRect: notch, expanded: true)
        #expect(expanded.maxX == left.maxX)
        #expect(expanded.width > left.width)
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
}
