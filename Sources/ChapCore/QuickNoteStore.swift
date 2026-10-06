import Foundation

/// 노치 빠른 메모의 저장소. 평문 한 파일을 원자적으로 읽고 쓴다.
/// 위치: `~/Library/Application Support/Chap/QuickNote.txt`. 설정 파일과 분리해
/// 설정 Export/Import에 메모 내용이 섞이지 않게 한다.
public struct QuickNoteStore: Sendable {
    /// 메모 최대 길이(문자). 노치 한 칸에 맞는 메모장이라 넉넉하되 한정한다.
    public static let maxLength = 20_000

    public let fileURL: URL

    public init(fileURL: URL = QuickNoteStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Chap", isDirectory: true)
            .appendingPathComponent("QuickNote.txt")
    }

    /// 파일이 없거나 읽을 수 없으면 빈 메모다.
    public func load() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    /// 마지막 저장 시각. 파일이 없으면 nil.
    public func lastSavedDate() -> Date? {
        (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
    }

    /// 메모 오른쪽 아래의 저장 표시: "Saved · 6:12 PM"(오늘), "Saved · Oct 4, 6:12 PM"(올해),
    /// "Saved · Oct 4, 2025, 6:12 PM"(다른 해). 언제 저장됐는지 날짜까지 그대로 보여 준다.
    public static func savedLabel(
        for date: Date?, now: Date = Date(), calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String? {
        guard let date else { return nil }
        var calendar = calendar
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy, h:mm a"
        }
        return "Saved · " + formatter.string(from: date)
    }

    /// 상한을 넘는 부분은 잘라 저장하고, 실제로 저장한 내용을 돌려준다.
    @discardableResult
    public func save(_ text: String) throws -> String {
        let clamped = Self.clamped(text)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(clamped.utf8).write(to: fileURL, options: .atomic)
        return clamped
    }

    /// 메모 도구 줄의 글자 수 표시. 상한의 90%를 넘으면 남은 여유가 보이도록 상한도 함께 적는다.
    public static func characterCountLabel(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        let value = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        if count * 10 >= maxLength * 9 {
            let limit = formatter.string(from: NSNumber(value: maxLength)) ?? "\(maxLength)"
            return "\(value) / \(limit) chars"
        }
        return count == 1 ? "1 char" : "\(value) chars"
    }

    public static func clamped(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) : text
    }
}
