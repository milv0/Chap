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

    /// 상한을 넘는 부분은 잘라 저장하고, 실제로 저장한 내용을 돌려준다.
    @discardableResult
    public func save(_ text: String) throws -> String {
        let clamped = Self.clamped(text)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(clamped.utf8).write(to: fileURL, options: .atomic)
        return clamped
    }

    public static func clamped(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) : text
    }
}
