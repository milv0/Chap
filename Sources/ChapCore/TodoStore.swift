import Foundation

/// 노치 할 일(To-do) 한 항목.
public struct TodoItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool
    public let created: Date
    /// 완료한 시각. 완료 항목은 이 순서로 목록 아래에 모인다.
    public var completed: Date?

    public init(
        id: UUID = UUID(), title: String, isDone: Bool = false, created: Date = Date(),
        completed: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.created = created
        self.completed = completed
    }
}

/// 노치 할 일 목록의 규칙과 저장소. Chap 안에만 저장하고(권한 없음, 동기화 없음) 설정 Export/Import에
/// 섞이지 않는다. 위치: `~/Library/Application Support/Chap/Todos.json`.
public struct TodoStore: Sendable {
    /// 담을 수 있는 최대 항목 수. 노치 한 칸을 짧게 유지한다.
    public static let maxItems = 20
    /// 한 항목 문구의 최대 길이(문자).
    public static let maxTitleLength = 200
    /// 스크롤 없이 보이는 줄 수. 다른 목록 칸과 같은 4줄.
    public static let visibleRows = 4

    public let fileURL: URL

    public init(fileURL: URL = TodoStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Chap", isDirectory: true)
            .appendingPathComponent("Todos.json")
    }

    // MARK: - 파일

    /// 파일이 없거나 읽을 수 없으면 빈 목록이다. 상한을 넘는 뒤쪽 항목은 버리지 않고 그대로 읽는다.
    public func load() -> [TodoItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TodoItem].self, from: data)) ?? []
    }

    public func save(_ items: [TodoItem]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: fileURL, options: .atomic)
    }

    // MARK: - 규칙 (순수 함수)

    /// 저장할 문구: 앞뒤 공백·줄바꿈을 지우고 한 줄로, 상한 길이로 자른다. 비면 nil.
    public static func cleanedTitle(_ raw: String) -> String? {
        let oneLine = raw.components(separatedBy: .newlines).joined(separator: " ")
        let trimmed = oneLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > maxTitleLength ? String(trimmed.prefix(maxTitleLength)) : trimmed
    }

    /// 더 넣을 수 있는지.
    public static func canAdd(_ items: [TodoItem]) -> Bool { items.count < maxItems }

    /// 새 항목을 맨 뒤(할 일 중 마지막)에 더한다. 빈 문구거나 꽉 찼으면 그대로 돌려준다.
    public static func adding(_ raw: String, to items: [TodoItem], now: Date = Date())
        -> [TodoItem]
    {
        guard canAdd(items), let title = cleanedTitle(raw) else { return items }
        return items + [TodoItem(title: title, created: now)]
    }

    /// 완료를 켜고 끈다.
    public static func toggling(_ id: UUID, in items: [TodoItem], now: Date = Date()) -> [TodoItem]
    {
        items.map { item in
            guard item.id == id else { return item }
            var item = item
            item.isDone.toggle()
            item.completed = item.isDone ? now : nil
            return item
        }
    }

    /// 문구를 고친다. 비우면 항목을 지운다.
    public static func renaming(_ id: UUID, to raw: String, in items: [TodoItem]) -> [TodoItem] {
        guard let title = cleanedTitle(raw) else { return removing(id, from: items) }
        return items.map { item in
            guard item.id == id else { return item }
            var item = item
            item.title = title
            return item
        }
    }

    public static func removing(_ id: UUID, from items: [TodoItem]) -> [TodoItem] {
        items.filter { $0.id != id }
    }

    public static func clearingCompleted(_ items: [TodoItem]) -> [TodoItem] {
        items.filter { !$0.isDone }
    }

    /// 보여 줄 순서: 할 일은 넣은 순, 그 아래 완료 항목은 완료한 순.
    public static func ordered(_ items: [TodoItem]) -> [TodoItem] {
        let open = items.filter { !$0.isDone }.sorted { $0.created < $1.created }
        let done = items.filter(\.isDone).sorted {
            ($0.completed ?? $0.created) < ($1.completed ?? $1.created)
        }
        return open + done
    }

    /// 칸 제목 옆 짧은 개수: 남은 할 일 수. 없으면 nil.
    public static func remainingLabel(_ items: [TodoItem]) -> String? {
        let open = items.filter { !$0.isDone }.count
        return open > 0 ? "\(open)" : nil
    }
}
