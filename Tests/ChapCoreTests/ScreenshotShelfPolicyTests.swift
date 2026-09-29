import Foundation
import Testing

@testable import Chap

@Suite("ScreenshotShelfPolicy")
struct ScreenshotShelfPolicyTests {
    @Test("image extensions qualify regardless of case")
    func imageExtensionsQualify() {
        #expect(ScreenshotShelfPolicy.isCandidate(fileName: "Screenshot.png"))
        #expect(ScreenshotShelfPolicy.isCandidate(fileName: "photo.JPG"))
        #expect(ScreenshotShelfPolicy.isCandidate(fileName: "shot.HEIC"))
    }

    @Test("non-image and hidden files are excluded")
    func nonImagesExcluded() {
        #expect(ScreenshotShelfPolicy.isCandidate(fileName: "notes.txt") == false)
        #expect(ScreenshotShelfPolicy.isCandidate(fileName: "movie.mov") == false)
        #expect(ScreenshotShelfPolicy.isCandidate(fileName: ".DS_Store") == false)
        #expect(ScreenshotShelfPolicy.isCandidate(fileName: ".hidden.png") == false)
    }

    @Test("selection returns newest first capped at the limit")
    func selectionNewestFirstCapped() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let files = (0..<8).map { index in
            (name: "s\(index).png", modified: base.addingTimeInterval(Double(index)))
        }

        let selected = ScreenshotShelfPolicy.shelfSelection(files: files)

        #expect(selected.count == ScreenshotShelfPolicy.maxItems)
        #expect(selected.first == "s7.png")
        #expect(selected.last == "s4.png")
    }

    @Test("selection filters out non-candidates before capping")
    func selectionFiltersNonCandidates() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let files = [
            (name: "new.txt", modified: base.addingTimeInterval(10)),
            (name: "old.png", modified: base),
        ]

        let selected = ScreenshotShelfPolicy.shelfSelection(files: files)

        #expect(selected == ["old.png"])
    }

    @Test("shelf rows show a short relative time instead of the file name")
    func relativeLabels() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 15))!
        func label(_ seconds: TimeInterval) -> String {
            ScreenshotShelfPolicy.relativeLabel(for: now.addingTimeInterval(-seconds), now: now)
        }
        #expect(label(20) == "Just now")
        #expect(label(5 * 60) == "5 min ago")
        #expect(label(3600) == "1 hr ago")
        #expect(label(3 * 3600) == "3 hr ago")
        #expect(label(20 * 3600) == "Yesterday")
        #expect(label(5 * 86400) == "Sep 24")
    }
}
