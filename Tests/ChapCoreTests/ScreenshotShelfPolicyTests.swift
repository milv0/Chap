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
}
