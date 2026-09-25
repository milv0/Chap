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

    @Test("the drop badge is a square body with the flare outside it")
    func dropBadgeSquareBodyWithFlare() {
        let frame = NotchLauncherPolicy.dropBadgeFrame(
            notchRect: CGRect(x: 656, y: 950, width: 200, height: 32))

        // 856(노치 오른쪽 끝) 기준: 겹침 12 + 정사각형 32 + 플레어 10.
        #expect(frame.minX == 856 - NotchLauncherPolicy.dropBadgeNotchOverlap)
        #expect(frame.maxX == 898)
        #expect(frame.minY == 950)
        #expect(frame.height == 32)
    }

    @Test("the drop badge shows only when files exist")
    func dropBadgeVisibility() {
        #expect(NotchLauncherPolicy.shouldShowDropBadge(fileCount: 1))
        #expect(NotchLauncherPolicy.shouldShowDropBadge(fileCount: 0) == false)
    }
}
