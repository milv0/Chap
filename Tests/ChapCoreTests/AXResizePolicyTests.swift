import CoreGraphics
import Testing

@testable import Chap

@Suite("AX Resize Policy")
struct AXResizePolicyTests {
    @Test("apply order is size then position then size")
    func applyOrderMatchesRectangle() {
        // macOS는 size를 현재 디스플레이에 맞춰 클램프하므로 다른 디스플레이로 옮길 때
        // size → position → size 순서가 필요하다 (Rectangle과 동일).
        #expect(AXResizePolicy.applyOrder == [.size, .position, .size])
    }

    @Test("center preserving origin shifts by half the size delta")
    func centerPreservingOriginLargerActual() {
        let origin = AXResizePolicy.centerPreservingOrigin(
            requestedOrigin: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            actualSize: CGSize(width: 1000, height: 700))
        #expect(origin == CGPoint(x: 0, y: 150))
    }

    @Test("center preserving origin is unchanged for identical sizes")
    func centerPreservingOriginIdenticalSizes() {
        let origin = AXResizePolicy.centerPreservingOrigin(
            requestedOrigin: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            actualSize: CGSize(width: 800, height: 600))
        #expect(origin == CGPoint(x: 100, y: 200))
    }

    @Test("center preserving origin shifts inward for smaller actual size")
    func centerPreservingOriginSmallerActual() {
        let origin = AXResizePolicy.centerPreservingOrigin(
            requestedOrigin: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            actualSize: CGSize(width: 600, height: 500))
        #expect(origin == CGPoint(x: 200, y: 250))
    }

    @Test("no adjustment when actual size is unreadable")
    func noAdjustmentForUnreadableSize() {
        #expect(
            !AXResizePolicy.needsCenterPreservingAdjustment(
                requestedSize: CGSize(width: 800, height: 600),
                actualSize: nil,
                tolerance: 4))
    }

    @Test("no adjustment when actual size is within tolerance")
    func noAdjustmentWithinTolerance() {
        #expect(
            !AXResizePolicy.needsCenterPreservingAdjustment(
                requestedSize: CGSize(width: 800, height: 600),
                actualSize: CGSize(width: 803, height: 597),
                tolerance: 4))
    }

    @Test("adjustment needed when the app clamps one axis beyond tolerance")
    func adjustmentNeededBeyondTolerance() {
        #expect(
            AXResizePolicy.needsCenterPreservingAdjustment(
                requestedSize: CGSize(width: 800, height: 600),
                actualSize: CGSize(width: 900, height: 600),
                tolerance: 4))
    }

    @Test("no minimum size clamp predicted without a minimum size")
    func noClampWithoutMinimumSize() {
        #expect(
            !AXResizePolicy.predictsMinimumSizeClamp(
                requestedSize: CGSize(width: 800, height: 600),
                minimumSize: nil))
    }

    @Test("minimum size clamp predicted when requested width is below minimum")
    func clampPredictedBelowMinimumWidth() {
        #expect(
            AXResizePolicy.predictsMinimumSizeClamp(
                requestedSize: CGSize(width: 800, height: 600),
                minimumSize: CGSize(width: 900, height: 100)))
    }

    @Test("no clamp predicted when requested size meets the minimum")
    func noClampAtOrAboveMinimum() {
        #expect(
            !AXResizePolicy.predictsMinimumSizeClamp(
                requestedSize: CGSize(width: 800, height: 600),
                minimumSize: CGSize(width: 800, height: 600)))
    }

    @Test("enhanced UI is restored only when it was originally enabled")
    func enhancedUIRestorePolicy() {
        #expect(AXResizePolicy.shouldRestoreEnhancedUI(originalValue: true))
        #expect(!AXResizePolicy.shouldRestoreEnhancedUI(originalValue: false))
        #expect(!AXResizePolicy.shouldRestoreEnhancedUI(originalValue: nil))
    }
}

@Suite("Derived Window Number")
struct DerivedWindowNumberTests {
    @Test("derived ids always set the high bit to avoid real window id space")
    func derivedIdSetsHighBit() {
        #expect(AXIntrospection.derivedWindowNumber(fromElementHash: 5) == 0x8000_0005)
        #expect(
            AXIntrospection.derivedWindowNumber(fromElementHash: 0) & 0x8000_0000 == 0x8000_0000)
    }

    @Test("derived ids keep only the low 31 bits of the hash")
    func derivedIdMasksLowBits() {
        #expect(
            AXIntrospection.derivedWindowNumber(fromElementHash: 0xFFFF_FFFF) == 0xFFFF_FFFF)
        let high = AXIntrospection.derivedWindowNumber(fromElementHash: (1 << 40) | 7)
        #expect(high == 0x8000_0007)
    }

    @Test("derived ids are stable for the same hash")
    func derivedIdIsDeterministic() {
        let first = AXIntrospection.derivedWindowNumber(fromElementHash: 12345)
        let second = AXIntrospection.derivedWindowNumber(fromElementHash: 12345)
        #expect(first == second)
    }
}
