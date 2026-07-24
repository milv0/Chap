import Foundation
import Testing

@testable import Chap

@Suite("AXBoundsResult Determination")
struct AXBoundsResultTests {
    @Test("fully applied when both position and size within tolerance")
    func fullyApplied() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 102, y: 200),
            actualSize: CGSize(width: 798, height: 601),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 4.0
        )
        #expect(level == .fullyApplied)
    }

    @Test("partially applied when only position is within tolerance")
    func partialPositionOnly() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 100, y: 200),
            actualSize: CGSize(width: 750, height: 600),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 4.0
        )
        #expect(level == .partiallyApplied)
    }

    @Test("partially applied when only size is within tolerance")
    func partialSizeOnly() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 50, y: 50),
            actualSize: CGSize(width: 800, height: 600),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 4.0
        )
        #expect(level == .partiallyApplied)
    }

    @Test("failed when both position and size exceed tolerance")
    func failedBothOff() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 50, y: 50),
            actualSize: CGSize(width: 700, height: 500),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 4.0
        )
        #expect(level == .failed)
    }

    @Test("fails verification when actual values cannot be read back")
    func missingReadbackFails() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: nil,
            actualSize: nil,
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600)
        )
        #expect(level == .failed)
    }

    @Test("partially applied when only one value can be verified")
    func oneReadbackIsPartial() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 100, y: 200),
            actualSize: nil,
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600)
        )
        #expect(level == .partiallyApplied)
    }

    @Test("both AX errors mean failed when no actual values")
    func bothErrorsMeanFailed() {
        let level = AXBoundsResult.determineLevel(
            positionError: .failure,
            sizeError: .failure,
            actualPosition: nil,
            actualSize: nil,
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600)
        )
        #expect(level == .failed)
    }

    @Test("AX success codes do not replace readback verification")
    func successCodesWithoutReadbackFail() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: nil,
            actualSize: nil,
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600)
        )
        #expect(level == .failed)
    }

    @Test("exact match is fully applied")
    func exactMatch() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 100, y: 200),
            actualSize: CGSize(width: 800, height: 600),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 4.0
        )
        #expect(level == .fullyApplied)
    }

    @Test("boundary tolerance value — exactly at tolerance is within")
    func boundaryTolerance() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 104, y: 204),
            actualSize: CGSize(width: 804, height: 604),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 4.0
        )
        #expect(level == .fullyApplied)
    }

    @Test("just beyond tolerance is not within")
    func beyondTolerance() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 105, y: 200),
            actualSize: CGSize(width: 800, height: 600),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 4.0
        )
        #expect(level == .partiallyApplied)
    }

    @Test("custom tolerance value respected")
    func customTolerance() {
        let level = AXBoundsResult.determineLevel(
            positionError: .success,
            sizeError: .success,
            actualPosition: CGPoint(x: 110, y: 200),
            actualSize: CGSize(width: 800, height: 600),
            requestedPosition: CGPoint(x: 100, y: 200),
            requestedSize: CGSize(width: 800, height: 600),
            tolerance: 10.0
        )
        #expect(level == .fullyApplied)
    }
}

@Suite("AppLauncher Window Policy")
struct AppLauncherWindowPolicyTests {
    @Test("running app uses a short focused fallback delay")
    func runningAppUsesShortFallbackDelay() {
        #expect(AppLauncher.focusedFallbackDelay(appRunning: true, timeout: 30) == 0.2)
    }

    @Test("cold app preserves the full new-window timeout")
    func coldAppPreservesTimeout() {
        #expect(AppLauncher.focusedFallbackDelay(appRunning: false, timeout: 30) == 30)
    }

    @Test("standard resizable AXWindow is eligible")
    func standardWindowIsEligible() {
        #expect(
            AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: "AXStandardWindow",
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: false))
    }

    @Test("AXHelpTag is never eligible")
    func helpTagIsRejected() {
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: "AXHelpTag", subrole: nil,
                canSetPosition: true, canSetSize: false, isMicrosoftOffice: true))
    }

    @Test("Office allows resizable non-standard AXWindow")
    func officeNonStandardWindowIsEligible() {
        #expect(
            AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: nil,
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: true))
    }

    @Test("non-Office rejects non-standard AXWindow")
    func nonOfficeRejectsNonStandardWindow() {
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: nil,
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: false))
    }

    @Test("unresizable window is rejected")
    func unresizableWindowIsRejected() {
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: "AXStandardWindow",
                canSetPosition: true, canSetSize: false, isMicrosoftOffice: true))
    }
}
