import Foundation
import Testing

@testable import Chap

@Suite("Fitted Size")
struct FittedSizeTests {
    @Test("keeps size unchanged when it already fits")
    func noScaleWhenFits() {
        let result = fittedSize(
            requestedWidth: 800, requestedHeight: 600, maxWidth: 1000, maxHeight: 1000)
        #expect(result.width == 800)
        #expect(result.height == 600)
    }

    @Test("scales down preserving aspect ratio when too wide")
    func scalesDownPreservingRatio() {
        // 2000x1000 into 1000x1000 → scale 0.5 → 1000x500
        let result = fittedSize(
            requestedWidth: 2000, requestedHeight: 1000, maxWidth: 1000, maxHeight: 1000)
        #expect(result.width == 1000)
        #expect(result.height == 500)
    }

    @Test("limiting dimension is height")
    func scalesByHeight() {
        // 1000x2000 into 1000x1000 → scale 0.5 → 500x1000
        let result = fittedSize(
            requestedWidth: 1000, requestedHeight: 2000, maxWidth: 1000, maxHeight: 1000)
        #expect(result.width == 500)
        #expect(result.height == 1000)
    }

    @Test("clamps tiny requests to a 100pt floor")
    func clampsMinimum() {
        let result = fittedSize(
            requestedWidth: 10, requestedHeight: 10, maxWidth: 1000, maxHeight: 1000)
        #expect(result.width == 100)
        #expect(result.height == 100)
    }
}

@Suite("Window Size From Ratio")
struct WindowSizeFromRatioTests {
    @Test("computes width and height from ratios without aspect")
    func ratioNoAspect() {
        let result = windowSizeFromRatio(
            widthRatio: 0.5, heightRatio: 0.5, aspectRatio: nil,
            visibleWidth: 1000, visibleHeight: 800)
        #expect(result.width == 500)
        #expect(result.height == 400)
    }

    @Test("derives height from aspect ratio when provided")
    func withAspect() {
        // width = 1000*0.8 = 800, height = 800/2.0 = 400
        let result = windowSizeFromRatio(
            widthRatio: 0.8, heightRatio: 0.5, aspectRatio: 2.0,
            visibleWidth: 1000, visibleHeight: 800)
        #expect(result.width == 800)
        #expect(result.height == 400)
    }

    @Test("result never exceeds the visible area")
    func fitsWithinVisible() {
        let result = windowSizeFromRatio(
            widthRatio: 1.0, heightRatio: 1.0, aspectRatio: nil,
            visibleWidth: 900, visibleHeight: 700)
        #expect(result.width <= 900)
        #expect(result.height <= 700)
    }
}

@Suite("Centered Bounds")
struct CenteredBoundsTests {
    @Test("centers a window in the visible frame (primary screen origin)")
    func centersOnPrimary() {
        // visibleFrame 0,0 1000x1000, primary height 1000, window 400x200
        let bounds = centeredBounds(
            fittedWidth: 400, fittedHeight: 200,
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            primaryHeight: 1000)
        #expect(bounds.left == 300)
        #expect(bounds.top == 400)
        #expect(bounds.right == 700)
        #expect(bounds.bottom == 600)
    }

    @Test("accounts for a secondary screen offset and menu-bar inset")
    func centersOnSecondary() {
        // Secondary screen to the right: visibleFrame x=1000, y=0, 800x600 within a 1000-tall primary.
        // bx = 1000 + (800-400)/2 = 1200
        // by = 1000 - 600 + (600-300)/2 = 400 + 150 = 550
        let bounds = centeredBounds(
            fittedWidth: 400, fittedHeight: 300,
            visibleFrame: CGRect(x: 1000, y: 0, width: 800, height: 600),
            primaryHeight: 1000)
        #expect(bounds.left == 1200)
        #expect(bounds.top == 550)
        #expect(bounds.right == 1600)
        #expect(bounds.bottom == 850)
    }
}

@Suite("AppKit Frame Conversion")
struct AppKitFrameTests {
    @Test("converts top-left origin bounds to bottom-left AppKit rect")
    func convertsTopLeftToBottomLeft() {
        // bounds left=100, top=50, right=500, bottom=350 → w=400, h=300
        // y = primaryHeight(1000) - top(50) - height(300) = 650
        let rect = appKitFrame(
            fromTopLeft: (left: 100, top: 50, right: 500, bottom: 350),
            primaryHeight: 1000)
        #expect(rect.origin.x == 100)
        #expect(rect.origin.y == 650)
        #expect(rect.size.width == 400)
        #expect(rect.size.height == 300)
    }

    @Test("round-trips with centeredBounds on the primary screen")
    func roundTripWithCenteredBounds() {
        // A window centered on the primary screen should convert back to a rect
        // whose size matches and which sits within the visible frame.
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let bounds = centeredBounds(
            fittedWidth: 600, fittedHeight: 400, visibleFrame: visible, primaryHeight: 900)
        let rect = appKitFrame(
            fromTopLeft: (bounds.left, bounds.top, bounds.right, bounds.bottom),
            primaryHeight: 900)
        #expect(rect.size.width == 600)
        #expect(rect.size.height == 400)
        #expect(rect.origin.x == 420)  // (1440-600)/2
        #expect(rect.origin.y == 250)  // 900 - top(250) - 400; top = (900-400)/2 = 250
    }
}
