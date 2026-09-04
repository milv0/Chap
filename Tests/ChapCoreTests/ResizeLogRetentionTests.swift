import Foundation
import Testing

@testable import Chap

@Suite("Resize Log Retention")
struct ResizeLogRetentionTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("files older than the retention window are stale")
    func oldFilesAreStale() {
        let now = date(2026, 9, 1)
        let names = ["resize_2026-07-08.csv", "resize_2026-08-01.csv"]

        let stale = ResizeLogRetention.staleFileNames(
            in: names, now: now, maxAgeDays: 14, calendar: calendar)

        #expect(stale == names)
    }

    @Test("files within the retention window are kept")
    func recentFilesAreKept() {
        let now = date(2026, 9, 1)
        let names = ["resize_2026-08-25.csv", "resize_2026-09-01.csv"]

        let stale = ResizeLogRetention.staleFileNames(
            in: names, now: now, maxAgeDays: 14, calendar: calendar)

        #expect(stale.isEmpty)
    }

    @Test("a file exactly at the retention boundary is kept")
    func boundaryFileIsKept() {
        let now = date(2026, 9, 1)

        let stale = ResizeLogRetention.staleFileNames(
            in: ["resize_2026-08-18.csv"], now: now, maxAgeDays: 14, calendar: calendar)

        #expect(stale.isEmpty)
    }

    @Test("a file one day past the boundary is stale")
    func dayPastBoundaryIsStale() {
        let now = date(2026, 9, 1)

        let stale = ResizeLogRetention.staleFileNames(
            in: ["resize_2026-08-17.csv"], now: now, maxAgeDays: 14, calendar: calendar)

        #expect(stale == ["resize_2026-08-17.csv"])
    }

    @Test(
        "non-matching or malformed file names are never stale",
        arguments: [
            "appcast.xml",
            "resize_.csv",
            "resize_2026-08-17.txt",
            "notes_2026-01-01.csv",
            "resize_2026-13-01.csv",
            "resize_2026-02-30.csv",
            "resize_26-08-17.csv",
        ])
    func malformedNamesAreIgnored(name: String) {
        let now = date(2026, 9, 1)

        let stale = ResizeLogRetention.staleFileNames(
            in: [name], now: now, maxAgeDays: 14, calendar: calendar)

        #expect(stale.isEmpty)
    }

    @Test("parses a valid log file date")
    func parsesValidDate() {
        let parsed = ResizeLogRetention.logDate(
            fromFileName: "resize_2026-08-17.csv", calendar: calendar)

        #expect(parsed == date(2026, 8, 17))
    }

    @Test("mixed listing returns only the stale entries")
    func mixedListingFiltersCorrectly() {
        let now = date(2026, 9, 1)
        let names = [
            "resize_2026-07-08.csv",
            "resize_2026-08-25.csv",
            "appcast.xml",
            "resize_2026-08-10.csv",
        ]

        let stale = ResizeLogRetention.staleFileNames(
            in: names, now: now, maxAgeDays: 14, calendar: calendar)

        #expect(stale == ["resize_2026-07-08.csv", "resize_2026-08-10.csv"])
    }
}
