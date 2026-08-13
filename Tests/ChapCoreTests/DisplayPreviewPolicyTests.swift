import Foundation
import Testing

@testable import Chap

@Suite("Display Preview Policy")
struct DisplayPreviewPolicyTests {
    @Test("overview keeps the full name when a display is readable")
    func overviewUsesDisplayNameAtReadableSize() {
        let label = DisplayPreviewPolicy.overviewLabel(
            displayName: "Studio Display",
            displayIndex: 0,
            renderedSize: CGSize(width: 128, height: 72))

        #expect(label == "Studio Display")
    }

    @Test("overview uses an ordinal badge instead of shrinking a small display name")
    func overviewUsesOrdinalBadgeAtSmallSize() {
        let label = DisplayPreviewPolicy.overviewLabel(
            displayName: "Portable Display",
            displayIndex: 2,
            renderedSize: CGSize(width: 58, height: 36))

        #expect(label == "3")
    }

    @Test("selected detail fits a widescreen display independently of topology bounds")
    func detailFitsWideDisplayInItsOwnCanvas() {
        let size = DisplayPreviewPolicy.detailDisplaySize(
            displaySize: CGSize(width: 2560, height: 1440),
            availableSize: CGSize(width: 300, height: 180))

        #expect(size.width <= 300)
        #expect(size.height <= 180)
        #expect(abs((size.width / size.height) - (2560.0 / 1440.0)) < 0.001)
        #expect(size.width > 240)
        #expect(size.width < 250)
    }

    @Test("selected detail preserves a portrait display aspect ratio")
    func detailPreservesPortraitDisplayAspectRatio() {
        let size = DisplayPreviewPolicy.detailDisplaySize(
            displaySize: CGSize(width: 1080, height: 1920),
            availableSize: CGSize(width: 300, height: 180))

        #expect(size.width > 0)
        #expect(size.height > 0)
        #expect(abs((size.width / size.height) - (1080.0 / 1920.0)) < 0.001)
    }
}
