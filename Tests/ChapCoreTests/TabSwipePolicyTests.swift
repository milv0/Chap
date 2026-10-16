import Testing

@testable import Chap

@Suite("TabSwipeTracker – trackpad swipe between tabs")
struct TabSwipeTrackerTests {
    @Test("a left swipe past the threshold goes to the next tab once")
    func leftSwipeStepsOnce() {
        var tracker = TabSwipeTracker()
        #expect(tracker.step(phase: .began, fingerDX: -10, deltaY: 0) == nil)
        #expect(tracker.step(phase: .changed, fingerDX: -16, deltaY: 1) == 1)
        // 같은 제스처에서 더 밀어도 한 칸만 넘긴다.
        #expect(tracker.step(phase: .changed, fingerDX: -40, deltaY: 0) == nil)
        #expect(tracker.step(phase: .ended, fingerDX: 0, deltaY: 0) == nil)
    }

    @Test("a right swipe goes to the previous tab")
    func rightSwipeGoesBack() {
        var tracker = TabSwipeTracker()
        _ = tracker.step(phase: .began, fingerDX: 12, deltaY: 0)
        #expect(tracker.step(phase: .changed, fingerDX: 14, deltaY: 0) == -1)
    }

    @Test("momentum after lifting the fingers never steps")
    func momentumIgnored() {
        var tracker = TabSwipeTracker()
        _ = tracker.step(phase: .began, fingerDX: -5, deltaY: 0)
        _ = tracker.step(phase: .ended, fingerDX: 0, deltaY: 0)
        #expect(tracker.step(phase: .momentum, fingerDX: -80, deltaY: 0) == nil)
    }

    @Test("mostly vertical scrolling is left to the lists")
    func verticalIgnored() {
        var tracker = TabSwipeTracker()
        _ = tracker.step(phase: .began, fingerDX: -10, deltaY: 30)
        #expect(tracker.step(phase: .changed, fingerDX: -30, deltaY: 40) == nil)
        #expect(!TabSwipeTracker.isHorizontal(deltaX: 10, deltaY: 10))
        #expect(TabSwipeTracker.isHorizontal(deltaX: 20, deltaY: 10))
    }

    @Test("a new gesture can step again")
    func newGestureResets() {
        var tracker = TabSwipeTracker()
        _ = tracker.step(phase: .began, fingerDX: -30, deltaY: 0)
        _ = tracker.step(phase: .ended, fingerDX: 0, deltaY: 0)
        #expect(tracker.step(phase: .began, fingerDX: -30, deltaY: 0) == 1)
    }

    @Test("finger direction follows natural scrolling", arguments: [true, false])
    func fingerDirection(inverted: Bool) {
        // 자연스러운 스크롤이면 값이 손가락을 따르고, 아니면 반대다.
        let dx = TabSwipeTracker.fingerDX(scrollingDeltaX: -10, directionInverted: inverted)
        #expect(dx == (inverted ? -10 : 10))
    }
}

@Suite("TabStepPolicy – neighbouring tabs")
struct TabStepPolicyTests {
    private let ids = ["url", "finder"]

    @Test("steps within the tab order and stops at the ends")
    func target() {
        #expect(TabStepPolicy.target(ids: ids, current: "url", step: 1) == "finder")
        #expect(TabStepPolicy.target(ids: ids, current: "finder", step: -1) == "url")
        #expect(TabStepPolicy.target(ids: ids, current: "finder", step: 1) == nil)
        #expect(TabStepPolicy.target(ids: ids, current: "url", step: -1) == nil)
    }

    @Test("the blank header area always points at the other tab")
    func neighbor() {
        #expect(TabStepPolicy.neighbor(ids: ids, current: "url") == "finder")
        #expect(TabStepPolicy.neighbor(ids: ids, current: "finder") == "url")
        #expect(TabStepPolicy.neighbor(ids: ["layouts"], current: "layouts") == nil)
    }
}
