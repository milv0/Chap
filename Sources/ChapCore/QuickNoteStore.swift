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

    /// 메모 파일을 읽은 결과.
    public enum LoadResult: Equatable, Sendable {
        /// 읽었다. 파일이 없으면 빈 메모다.
        case text(String)
        /// 파일은 있는데 글자로 읽지 못했다. 원본을 `preservedAt`에 옮겨 두었으니 빈 메모로 새로 시작해도 된다.
        case preserved(at: URL)
        /// 파일을 열지도, 옮겨 두지도 못했다. 원본을 덮어쓰지 않도록 편집을 막아야 한다.
        case locked
    }

    /// 파일이 없으면 빈 메모, 읽지 못하면 원본을 백업 폴더로 옮기고 알린다. 읽지 못한 파일을 빈 메모로 착각해
    /// 다음 입력이 원본을 덮어쓰는 일을 막는다.
    public func loadResult(now: Date = Date()) -> LoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .text("") }
        guard let data = try? Data(contentsOf: fileURL) else { return .locked }
        if let text = String(data: data, encoding: .utf8) { return .text(text) }
        let preserved = backupDirectoryURL.appendingPathComponent(
            "QuickNote.unreadable-\(Self.stamp(now)).txt")
        do {
            try FileManager.default.createDirectory(
                at: backupDirectoryURL, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: fileURL, to: preserved)
            return .preserved(at: preserved)
        } catch {
            return .locked
        }
    }

    /// 읽은 글자. 읽지 못했으면 빈 메모다 (편집에는 `loadResult`를 쓴다).
    public func load() -> String {
        if case .text(let text) = loadResult() { return text }
        return ""
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
    /// 덮어쓰기 전에 `QuickNoteBackupPolicy`가 고르면 이전 내용을 백업 폴더에 남긴다(백업 실패는 저장을 막지 않는다).
    @discardableResult
    public func save(_ text: String, now: Date = Date()) throws -> String {
        let clamped = Self.clamped(text)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let previous = try? String(contentsOf: fileURL, encoding: .utf8),
            QuickNoteBackupPolicy.shouldBackUp(
                previous: previous, next: clamped, lastBackup: latestBackupDate(), now: now)
        {
            backUp(previous, now: now)
        }
        try Data(clamped.utf8).write(to: fileURL, options: .atomic)
        return clamped
    }

    // MARK: - 백업

    /// 이전 메모를 모아 두는 폴더: 메모 옆 `QuickNote Backups/`.
    public var backupDirectoryURL: URL {
        fileURL.deletingLastPathComponent()
            .appendingPathComponent("QuickNote Backups", isDirectory: true)
    }

    /// 백업 파일 이름 앞부분. 뒤에 `yyyyMMdd-HHmmss.txt`가 붙어 이름순이 곧 시간순이다.
    static let backupPrefix = "QuickNote-"

    /// 백업 폴더의 메모 백업, 오래된 것부터. 읽지 못해 옮겨 둔 원본(`unreadable`)은 세지 않고 지우지도 않는다.
    public func backupURLs() -> [URL] {
        let names =
            (try? FileManager.default.contentsOfDirectory(atPath: backupDirectoryURL.path)) ?? []
        return names.filter { Self.backupDate(fromName: $0) != nil }.sorted()
            .map { backupDirectoryURL.appendingPathComponent($0) }
    }

    func latestBackupDate() -> Date? {
        backupURLs().last.flatMap { Self.backupDate(fromName: $0.lastPathComponent) }
    }

    private func backUp(_ text: String, now: Date) {
        let url = backupDirectoryURL.appendingPathComponent(
            Self.backupPrefix + Self.stamp(now) + ".txt")
        do {
            try FileManager.default.createDirectory(
                at: backupDirectoryURL, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            return
        }
        for old in QuickNoteBackupPolicy.pruned(backupURLs()) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    static func backupDate(fromName name: String) -> Date? {
        guard name.hasPrefix(backupPrefix), name.hasSuffix(".txt") else { return nil }
        let stamp = name.dropFirst(backupPrefix.count).dropLast(4)
        return stampFormatter().date(from: String(stamp))
    }

    static func stamp(_ date: Date) -> String { stampFormatter().string(from: date) }

    private static func stampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
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

/// 메모 백업을 언제 남기고 몇 개를 둘지. 자동 저장은 0.5초마다 덮어쓰므로, 백업은 띄엄띄엄 남기되
/// 내용이 크게 줄어드는 순간(전체 선택 후 삭제 등)에는 바로 남긴다.
public enum QuickNoteBackupPolicy {
    /// 평소 백업 간격.
    public static let interval: TimeInterval = 10 * 60
    /// 남겨 두는 백업 수. 넘으면 오래된 것부터 지운다.
    public static let maxBackups = 10
    /// 이만큼 이상 긴 메모가 절반 넘게 줄면 간격과 상관없이 백업한다.
    public static let largeLossMinimumLength = 40

    /// 덮어쓰기 전에 이전 메모를 백업할지. 빈 메모와 바뀌지 않은 메모는 남기지 않는다.
    public static func shouldBackUp(previous: String, next: String, lastBackup: Date?, now: Date)
        -> Bool
    {
        guard previous != next,
            !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        if previous.count >= largeLossMinimumLength, next.count * 2 < previous.count {
            return true
        }
        guard let lastBackup else { return true }
        return now.timeIntervalSince(lastBackup) >= interval
    }

    /// 지울 백업(오래된 것부터 정렬된 목록에서 최신 `maxBackups`개를 뺀 나머지).
    public static func pruned(_ oldestFirst: [URL]) -> [URL] {
        Array(oldestFirst.dropLast(maxBackups))
    }
}
