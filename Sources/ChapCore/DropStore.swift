import Foundation

/// Chap Drop 보관함의 저장 규칙. 다른 선반 앱(Boring Notch, Yoink)처럼 Finder 파일은 **원본을 가리키는
/// 북마크**로만 기억하고 복사하지 않는다. 원본을 옮기거나 이름을 바꿔도 북마크가 따라가고, 원본을 지우면
/// 보관함에서도 사라진다. 임시 폴더처럼 곧 사라질 곳에서 온 파일만 보관함 폴더에 복사해 둔다.
///
/// 저장 위치: 보관함 폴더(`~/Library/Application Support/Chap/Drop/`)의 숨김 파일 `.references.json`.
/// 보관함 폴더에 직접 들어 있는 파일(2.7 이전의 복사본, 임시 파일 복사본)은 Chap이 가진 사본이다.
///
/// 이 타입은 동기 I/O만 한다. 앱은 직렬 큐(`ChapDrop`)에서만 부른다.
public struct DropStore {
    /// 보관함 한 항목.
    public struct Entry: Equatable {
        public let url: URL
        public let added: Date
        /// true면 원본을 가리키는 참조, false면 보관함 폴더 안의 Chap 사본.
        public let isReference: Bool
    }

    public let folder: URL
    /// 이 경로들 아래에서 온 파일은 참조 대신 사본을 둔다(곧 지워지는 임시 위치).
    public let copyPrefixes: [String]
    public var indexURL: URL { folder.appendingPathComponent(".references.json") }

    public init(folder: URL, copyPrefixes: [String] = DropStore.temporaryPrefixes) {
        self.folder = folder
        self.copyPrefixes = copyPrefixes
    }

    /// 임시 위치: 앱 임시 폴더, 사용자별 `/var/folders`, `/tmp`.
    public static var temporaryPrefixes: [String] {
        let temp = (NSTemporaryDirectory() as NSString).resolvingSymlinksInPath
        return [temp, "/private/var/folders/", "/var/folders/", "/private/tmp/", "/tmp/"]
    }

    private struct Reference: Codable {
        var bookmark: Data
        var added: Date
    }

    // MARK: - 규칙

    /// 곧 지워질 수 있는 임시 위치에서 온 파일이면 참조 대신 사본을 둔다.
    public func shouldCopy(path: String) -> Bool {
        let resolved = (path as NSString).resolvingSymlinksInPath
        return copyPrefixes.contains { !$0.isEmpty && resolved.hasPrefix($0) }
    }

    /// 같은 파일인지 비교할 표준 경로.
    static func canonicalPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// 보관함 폴더 안의 파일(Chap 사본)인지.
    public func isOwnedCopy(_ url: URL) -> Bool {
        let base = Self.canonicalPath(folder)
        return Self.canonicalPath(url).hasPrefix(base + "/")
    }

    // MARK: - 읽기

    /// 살아 있는 모든 항목, 최근에 넣은 순. 원본이 사라진 참조는 이때 정리한다.
    public func entries(now: Date = Date()) -> [Entry] {
        var references = loadReferences()
        var changed = false
        var result: [Entry] = []
        var seen = Set<String>()
        references = references.compactMap { reference in
            guard let resolved = Self.resolve(reference.bookmark) else {
                changed = true
                return nil
            }
            var reference = reference
            if resolved.isStale, let fresh = try? resolved.url.bookmarkData() {
                reference.bookmark = fresh
                changed = true
            }
            let path = Self.canonicalPath(resolved.url)
            guard seen.insert(path).inserted else {
                changed = true
                return nil
            }
            result.append(Entry(url: resolved.url, added: reference.added, isReference: true))
            return reference
        }
        if changed { saveReferences(references) }

        let owned =
            (try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])) ?? []
        for url in owned where DropPolicy.isCandidate(fileName: url.lastPathComponent) {
            let modified =
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            result.append(Entry(url: url, added: modified, isReference: false))
        }
        return result.sorted { $0.added > $1.added }
    }

    // MARK: - 쓰기

    /// 파일을 보관함에 넣는다. Finder 파일은 북마크 참조, 임시 위치 파일은 사본. 이미 있는 파일은
    /// 맨 앞으로 올린다. 반환: 넣은(또는 올린) 항목의 URL과 실패 수.
    @discardableResult
    public func add(_ sources: [URL], now: Date = Date()) -> (stored: [URL], failed: Int) {
        var references = loadReferences()
        var stored: [URL] = []
        var failed = 0
        for (offset, source) in sources.enumerated() {
            // 같은 드롭 안에서도 순서가 남도록 1ms씩 차이를 둔다.
            let added = now.addingTimeInterval(Double(offset) * 0.001)
            if isOwnedCopy(source) {
                stored.append(source)
                continue
            }
            if shouldCopy(path: source.path) {
                do {
                    let destination = availableDestination(for: source.lastPathComponent)
                    try FileManager.default.copyItem(at: source, to: destination)
                    stored.append(destination)
                } catch {
                    failed += 1
                }
                continue
            }
            let path = Self.canonicalPath(source)
            references.removeAll { reference in
                Self.resolve(reference.bookmark).map { Self.canonicalPath($0.url) } == path
            }
            guard let bookmark = try? source.bookmarkData() else {
                failed += 1
                continue
            }
            references.append(Reference(bookmark: bookmark, added: added))
            stored.append(source)
        }
        saveReferences(references)
        return (stored, failed)
    }

    /// 보관함에서 뺀다. 참조는 목록에서만 지우고 **원본 파일은 절대 건드리지 않는다**.
    /// 보관함 폴더 안의 Chap 사본만 실제로 삭제한다.
    @discardableResult
    public func remove(_ url: URL) -> Bool {
        if isOwnedCopy(url) {
            return (try? FileManager.default.removeItem(at: url)) != nil
        }
        var references = loadReferences()
        let path = Self.canonicalPath(url)
        let before = references.count
        references.removeAll { reference in
            Self.resolve(reference.bookmark).map { Self.canonicalPath($0.url) } == path
        }
        guard references.count != before else { return false }
        saveReferences(references)
        return true
    }

    // MARK: - 내부

    private static func resolve(_ bookmark: Data) -> (url: URL, isStale: Bool)? {
        var stale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                relativeTo: nil, bookmarkDataIsStale: &stale),
            FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return (url, stale)
    }

    private func loadReferences() -> [Reference] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([Reference].self, from: data)) ?? []
    }

    private func saveReferences(_ references: [Reference]) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(references) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func availableDestination(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = folder.appendingPathComponent(numbered)
            counter += 1
        }
        return candidate
    }
}
