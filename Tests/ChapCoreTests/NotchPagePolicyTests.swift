import CoreGraphics
import Testing

@testable import Chap

@Suite("Notch pages")
struct NotchPagePolicyTests {
    @Test("twelve slots split into three pages of four")
    func splitsIntoThreePages() {
        let slots = NotchWidget.normalizedSlots([
            .sites, .apps, .none, .none,
            .none, .folders, .none, .none,
            .none, .none, .none, .screenshots,
        ])

        let pages = NotchPagePolicy.pages(slots, empty: .none)

        #expect(pages.count == NotchWidget.pageCount)
        #expect(pages.allSatisfy { $0.count == NotchWidget.pageSize })
        #expect(pages[0] == [.sites, .apps, .none, .none])
        #expect(pages[1] == [.none, .folders, .none, .none])
        #expect(pages[2] == [.none, .none, .none, .screenshots])
    }

    @Test("a short slot array is padded so every page has four slots")
    func shortInputIsPadded() {
        let pages = NotchPagePolicy.pages([NotchWidget.sites], empty: .none)

        #expect(pages.count == 3)
        #expect(pages[0] == [.sites, .none, .none, .none])
        #expect(pages[2] == [.none, .none, .none, .none])
    }

    @Test("only pages with a widget are visible")
    func visiblePagesSkipEmptyOnes() {
        let slots = NotchWidget.normalizedSlots([
            .sites, .none, .none, .none,
            .none, .none, .none, .none,
            .apps, .none, .none, .none,
        ])

        #expect(NotchPagePolicy.visiblePageIndices(slots) == [0, 2])
        #expect(NotchPagePolicy.visiblePageIndices(NotchWidget.defaultSlots) == [0])
        #expect(NotchPagePolicy.visiblePageIndices(NotchWidget.normalizedSlots([])).isEmpty)
    }

    @Test("page dots appear only when more than one page is visible")
    func indicatorNeedsTwoPages() {
        #expect(!NotchPagePolicy.showsPageIndicator(visiblePageCount: 0))
        #expect(!NotchPagePolicy.showsPageIndicator(visiblePageCount: 1))
        #expect(NotchPagePolicy.showsPageIndicator(visiblePageCount: 2))
        #expect(NotchPagePolicy.showsPageIndicator(visiblePageCount: 3))
    }

    @Test("moving stops at the first and last page instead of wrapping")
    func positionClampsAtEnds() {
        #expect(NotchPagePolicy.position(from: 0, step: -1, count: 3) == 0)
        #expect(NotchPagePolicy.position(from: 0, step: 1, count: 3) == 1)
        #expect(NotchPagePolicy.position(from: 2, step: 1, count: 3) == 2)
        #expect(NotchPagePolicy.position(from: 5, step: 0, count: 2) == 1)
        #expect(NotchPagePolicy.position(from: 1, step: 1, count: 0) == 0)
    }

    @Test("the default layout fills only the first page")
    func defaultLayoutUsesFirstPage() {
        #expect(NotchWidget.slotCount == 12)
        #expect(
            Array(NotchWidget.defaultSlots.prefix(4)) == [.sites, .apps, .folders, .screenshots])
        #expect(NotchWidget.defaultSlots.dropFirst(4).allSatisfy { $0 == .none })
    }
}

@Suite("Notch page swipe")
struct NotchPageSwipeTrackerTests {
    @Test("a leftward finger swipe past the threshold goes to the next page once")
    func leftSwipeGoesNextOnce() {
        var tracker = NotchPageSwipeTracker()

        #expect(tracker.consume(deltaX: -20, deltaY: 0, began: true, ended: false) == nil)
        #expect(tracker.consume(deltaX: -20, deltaY: 0, began: false, ended: false) == 1)
        #expect(tracker.consume(deltaX: -80, deltaY: 0, began: false, ended: false) == nil)
        #expect(tracker.consume(deltaX: -5, deltaY: 0, began: false, ended: true) == nil)
    }

    @Test("a rightward finger swipe goes to the previous page")
    func rightSwipeGoesPrevious() {
        var tracker = NotchPageSwipeTracker()

        #expect(tracker.consume(deltaX: 50, deltaY: 0, began: true, ended: false) == -1)
    }

    @Test("a new gesture can turn the page again")
    func newGestureStepsAgain() {
        var tracker = NotchPageSwipeTracker()
        _ = tracker.consume(deltaX: -50, deltaY: 0, began: true, ended: true)

        #expect(tracker.consume(deltaX: -50, deltaY: 0, began: true, ended: false) == 1)
    }

    @Test("a mostly vertical scroll never turns the page")
    func verticalScrollIsIgnored() {
        var tracker = NotchPageSwipeTracker()

        #expect(tracker.consume(deltaX: -40, deltaY: 90, began: true, ended: false) == nil)
        #expect(tracker.consume(deltaX: -10, deltaY: 60, began: false, ended: true) == nil)
    }

    @Test("small movements below the threshold do nothing")
    func belowThresholdDoesNothing() {
        var tracker = NotchPageSwipeTracker()
        let almost = NotchPageSwipeTracker.threshold - 1

        #expect(tracker.consume(deltaX: -almost, deltaY: 0, began: true, ended: true) == nil)
    }
}
