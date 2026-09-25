import Foundation
import Testing

@testable import Chap

@Suite("DropPolicy")
struct DropPolicyTests {
    @Test("any non-hidden file qualifies regardless of extension")
    func anyVisibleFileQualifies() {
        #expect(DropPolicy.isCandidate(fileName: "report.pdf"))
        #expect(DropPolicy.isCandidate(fileName: "archive.zip"))
        #expect(DropPolicy.isCandidate(fileName: "photo.png"))
        #expect(DropPolicy.isCandidate(fileName: "no-extension"))
    }

    @Test("hidden files are excluded")
    func hiddenFilesExcluded() {
        #expect(DropPolicy.isCandidate(fileName: ".DS_Store") == false)
        #expect(DropPolicy.isCandidate(fileName: ".hidden") == false)
    }

    @Test("the dock limit shows more files than the slot widget")
    func dockLimitLargerThanSlot() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let files = (0..<20).map { index in
            (name: "f\(index).pdf", modified: base.addingTimeInterval(Double(index)))
        }

        let dock = DropPolicy.shelfSelection(files: files, limit: DropPolicy.maxDockItems)

        #expect(DropPolicy.maxDockItems > DropPolicy.maxItems)
        #expect(dock.count == DropPolicy.maxDockItems)
        #expect(dock.first == "f19.pdf")
    }

    @Test("selection returns newest first capped at four")
    func selectionNewestFirstCapped() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let files = (0..<6).map { index in
            (name: "f\(index).pdf", modified: base.addingTimeInterval(Double(index)))
        }

        let selected = DropPolicy.shelfSelection(files: files)

        #expect(DropPolicy.maxItems == 4)
        #expect(selected.count == 4)
        #expect(selected.first == "f5.pdf")
        #expect(selected.last == "f2.pdf")
    }
}
