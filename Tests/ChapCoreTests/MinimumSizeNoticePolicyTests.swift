import CoreGraphics
import Foundation
import Testing

@testable import Chap

@Suite("Minimum Size Notice Policy")
struct MinimumSizeNoticePolicyTests {
    @Test("no notice without a clamping minimum size")
    func noMinimumMeansNoNotice() {
        let notify = MinimumSizeNoticePolicy.shouldNotify(
            sizeApplied: false, clampingMinimumSize: nil)

        #expect(notify == false)
    }

    @Test("no notice when the requested size was applied despite a reported minimum")
    func appliedSizeMeansNoNotice() {
        let notify = MinimumSizeNoticePolicy.shouldNotify(
            sizeApplied: true, clampingMinimumSize: CGSize(width: 1200, height: 800))

        #expect(notify == false)
    }

    @Test("notice when clamped by a minimum and the size was not applied")
    func clampedUnappliedSizeNotifies() {
        let notify = MinimumSizeNoticePolicy.shouldNotify(
            sizeApplied: false, clampingMinimumSize: CGSize(width: 1200, height: 800))

        #expect(notify == true)
    }

    @Test("dedupe key combines site and requested size")
    func dedupeKeyIsStable() {
        let key = MinimumSizeNoticePolicy.dedupeKey(
            siteName: "Outlook", requestedSize: CGSize(width: 831, height: 519))

        #expect(key == "Outlook|831x519")
    }

    @Test("changing the requested size produces a different dedupe key")
    func dedupeKeyChangesWithSize() {
        let small = MinimumSizeNoticePolicy.dedupeKey(
            siteName: "Outlook", requestedSize: CGSize(width: 831, height: 519))
        let larger = MinimumSizeNoticePolicy.dedupeKey(
            siteName: "Outlook", requestedSize: CGSize(width: 1300, height: 769))

        #expect(small != larger)
    }

    @Test("message names the launchable")
    func messageNamesSite() {
        let message = MinimumSizeNoticePolicy.message(siteName: "Outlook")

        #expect(message.contains("Outlook"))
    }

    @Test("info includes both the minimum and the configured size")
    func infoIncludesBothSizes() {
        let info = MinimumSizeNoticePolicy.info(
            minimumSize: CGSize(width: 1200, height: 800),
            requestedSize: CGSize(width: 831, height: 519))

        #expect(info.contains("1200×800"))
        #expect(info.contains("831×519"))
    }
}
