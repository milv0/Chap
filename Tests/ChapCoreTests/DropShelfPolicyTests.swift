import Foundation
import Testing

@testable import Chap

@Suite("DropShelfPolicy")
struct DropShelfPolicyTests {
    @Test("any non-hidden file qualifies regardless of extension")
    func anyVisibleFileQualifies() {
        #expect(DropShelfPolicy.isCandidate(fileName: "report.pdf"))
        #expect(DropShelfPolicy.isCandidate(fileName: "archive.zip"))
        #expect(DropShelfPolicy.isCandidate(fileName: "photo.png"))
        #expect(DropShelfPolicy.isCandidate(fileName: "no-extension"))
    }

    @Test("hidden files are excluded")
    func hiddenFilesExcluded() {
        #expect(DropShelfPolicy.isCandidate(fileName: ".DS_Store") == false)
        #expect(DropShelfPolicy.isCandidate(fileName: ".hidden") == false)
    }

    @Test("selection returns newest first capped at four")
    func selectionNewestFirstCapped() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let files = (0..<6).map { index in
            (name: "f\(index).pdf", modified: base.addingTimeInterval(Double(index)))
        }

        let selected = DropShelfPolicy.shelfSelection(files: files)

        #expect(DropShelfPolicy.maxItems == 4)
        #expect(selected.count == 4)
        #expect(selected.first == "f5.pdf")
        #expect(selected.last == "f2.pdf")
    }
}
