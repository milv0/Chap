import Foundation
import Testing

@testable import Chap

@Suite("Downloads shelf")
struct DownloadsShelfPolicyTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("in-progress, hidden, and folder entries are skipped; apps are kept")
    func candidates() {
        #expect(DownloadsShelfPolicy.isCandidate(fileName: "report.pdf", isDirectory: false))
        #expect(!DownloadsShelfPolicy.isCandidate(fileName: ".DS_Store", isDirectory: false))
        #expect(
            !DownloadsShelfPolicy.isCandidate(fileName: "movie.mp4.crdownload", isDirectory: false))
        #expect(!DownloadsShelfPolicy.isCandidate(fileName: "file.zip.download", isDirectory: true))
        #expect(!DownloadsShelfPolicy.isCandidate(fileName: "data.part", isDirectory: false))
        #expect(!DownloadsShelfPolicy.isCandidate(fileName: "Photos", isDirectory: true))
        #expect(DownloadsShelfPolicy.isCandidate(fileName: "Tool.app", isDirectory: true))
    }

    @Test("finished downloads are shown newest first")
    func selection() {
        let files: [(name: String, isDirectory: Bool, date: Date)] = [
            ("old.pdf", false, now.addingTimeInterval(-500)),
            ("new.png", false, now.addingTimeInterval(-10)),
            ("partial.crdownload", false, now),
            ("mid.zip", false, now.addingTimeInterval(-100)),
            ("folder", true, now.addingTimeInterval(-5)),
            ("a.txt", false, now.addingTimeInterval(-200)),
            ("b.txt", false, now.addingTimeInterval(-300)),
        ]

        #expect(
            DownloadsShelfPolicy.shelfSelection(files: files)
                == ["new.png", "mid.zip", "a.txt", "b.txt", "old.pdf"])
    }

    @Test("the shelf keeps twelve downloads and shows four rows before scrolling")
    func limitAndVisibleRows() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let files = (0..<20).map { index in
            (
                name: "f\(index).pdf", isDirectory: false,
                date: base.addingTimeInterval(Double(index))
            )
        }
        let selected = DownloadsShelfPolicy.shelfSelection(files: files)
        #expect(selected.count == 12)
        #expect(selected.first == "f19.pdf")
        #expect(selected.last == "f8.pdf")
        #expect(DownloadsShelfPolicy.visibleRows == 4)
    }

    @Test("ages are short so the file name gets the width")
    func shortAge() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let afternoon = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 29, hour: 15))!
        func age(_ seconds: TimeInterval) -> String {
            DownloadsShelfPolicy.shortAge(
                of: afternoon.addingTimeInterval(-seconds), now: afternoon)
        }
        #expect(age(30) == "now")
        #expect(age(5 * 60) == "5m")
        #expect(age(3 * 3600) == "3h")
        #expect(age(20 * 3600) == "1d")
        #expect(age(5 * 86400) == "Sep 24")
    }

    @Test("downloads is a placeable widget that round-trips")
    func widgetRoundTrips() throws {
        let config = try JSONDecoder().decode(
            Config.self, from: Data(#"{"notchWidgets": ["downloads", "sites"], "sites": []}"#.utf8))
        // 선반은 앞쪽 선반 칸, 런처는 그 뒤 칸.
        #expect(config.notchWidgets == [.none, .downloads, .sites, .none, .none, .none])
        #expect(NotchWidget.downloads.launchType == nil)
    }

    @Test("the full-name bubble shows only for names cut short in the row")
    func fullNameOnlyWhenTruncated() {
        #expect(DownloadsShelfPolicy.needsFullName(idealWidth: 140, shownWidth: 92))
        #expect(!DownloadsShelfPolicy.needsFullName(idealWidth: 60, shownWidth: 92))
        // 반올림 오차(0.5pt 이내)는 잘린 것으로 보지 않는다.
        #expect(!DownloadsShelfPolicy.needsFullName(idealWidth: 92.4, shownWidth: 92))
        #expect(DownloadsShelfPolicy.fullNameRevealDelay > 0.2)
        #expect(DownloadsShelfPolicy.fullNameRevealDelay < 0.6)
    }
}
