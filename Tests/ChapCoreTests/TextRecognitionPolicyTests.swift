import CoreGraphics
import Foundation
import Testing

@testable import Chap

@Suite("Screen text recognition")
struct TextRecognitionPolicyTests {
    @Test("a drag in any direction becomes the same selection rectangle")
    func selectionFromAnyDirection() {
        let expected = CGRect(x: 10, y: 20, width: 100, height: 50)
        #expect(
            TextRecognitionPolicy.selectionRect(
                from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 70)) == expected)
        #expect(
            TextRecognitionPolicy.selectionRect(
                from: CGPoint(x: 110, y: 70), to: CGPoint(x: 10, y: 20)) == expected)
    }

    @Test("a click or a tiny drag cancels instead of capturing")
    func tinySelectionCancels() {
        #expect(
            TextRecognitionPolicy.selectionRect(
                from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5)) == nil)
        #expect(
            TextRecognitionPolicy.selectionRect(
                from: CGPoint(x: 0, y: 0), to: CGPoint(x: 200, y: 3)) == nil)
    }

    @Test("global AppKit coordinates flip to display-relative top-left capture coordinates")
    func captureRectFlipsToTopLeft() {
        // 1512x982 built-in display at the origin.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rect = CGRect(x: 100, y: 800, width: 200, height: 100)

        let capture = TextRecognitionPolicy.captureRect(forGlobalRect: rect, screenFrame: screen)

        #expect(capture == CGRect(x: 100, y: 82, width: 200, height: 100))
    }

    @Test("capture coordinates are relative to a secondary display and clipped to it")
    func captureRectOnSecondaryDisplay() {
        let screen = CGRect(x: 1512, y: -200, width: 2560, height: 1440)
        let rect = CGRect(x: 1400, y: 1100, width: 300, height: 200)

        let capture = TextRecognitionPolicy.captureRect(forGlobalRect: rect, screenFrame: screen)

        // Left 112pt off-screen is clipped; top edge 1300 → 1240 - 1240 = 0 after clipping to maxY.
        #expect(capture.minX == 0)
        #expect(capture.width == 188)
        #expect(capture.minY == 0)
        #expect(capture.height == 140)
    }

    @Test("lines are read top to bottom, and pieces on one row left to right")
    func joinedTextReadingOrder() {
        let lines = [
            TextRecognitionPolicy.Line(
                text: "world", box: CGRect(x: 0.5, y: 0.8, width: 0.3, height: 0.1)),
            TextRecognitionPolicy.Line(
                text: "second line", box: CGRect(x: 0.1, y: 0.5, width: 0.6, height: 0.1)),
            TextRecognitionPolicy.Line(
                text: "Hello", box: CGRect(x: 0.1, y: 0.81, width: 0.3, height: 0.1)),
            TextRecognitionPolicy.Line(
                text: "   ", box: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)),
        ]

        #expect(TextRecognitionPolicy.joinedText(lines) == "Hello world\nsecond line")
        #expect(TextRecognitionPolicy.joinedText([]).isEmpty)
    }

    @Test("the copied notice shows a short first line and counts the rest")
    func copiedMessage() {
        #expect(
            TextRecognitionPolicy.copiedMessage(for: "npm run build") == "Copied: npm run build")
        #expect(
            TextRecognitionPolicy.copiedMessage(for: "첫 줄\n둘째 줄") == "Copied: 첫 줄 (+1 line)")
        #expect(
            TextRecognitionPolicy.copiedMessage(for: "a\nb\nc") == "Copied: a (+2 lines)")
        let long = String(repeating: "x", count: 50)
        #expect(
            TextRecognitionPolicy.copiedMessage(for: long)
                == "Copied: \(String(repeating: "x", count: 32))…")
        #expect(TextRecognitionPolicy.copiedMessage(for: "  \n ") == nil)
    }

    @Test("recognition reads Korean and English")
    func languages() {
        #expect(TextRecognitionPolicy.recognitionLanguages == ["ko-KR", "en-US"])
    }

    @Test("the strip icon toggle defaults on and round-trips")
    func toggleRoundTrips() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.notchTextRecognitionEnabled)

        let off = Config(notchTextRecognitionEnabled: false, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: try JSONEncoder().encode(off))
        #expect(!decoded.notchTextRecognitionEnabled)
    }

    @Test("Drop box plus three strip tools fit in the 110pt status area")
    func fourStripIconsFit() {
        let offsets = NotchLauncherPolicy.stripToolCenterOffsets(besideDropBadge: true, count: 3)
        let pitch = NotchLauncherPolicy.stripToolPitch
        #expect(offsets.count == 3)
        #expect(offsets.last! + pitch / 2 <= NotchGeometry.stripPlateauSideWidth)
    }
}
