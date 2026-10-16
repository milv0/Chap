import Foundation

/// Layouts를 이 Mac에만 저장한다. Config import/export와 섞지 않는다.
public struct LayoutStore: Sendable {
    public static let maxLayouts = 4
    public static let maxWindows = 6
    public static let maxNameLength = 40

    public let fileURL: URL

    public init(fileURL: URL = LayoutStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Chap", isDirectory: true)
            .appendingPathComponent("Layouts.json")
    }

    /// 2.17까지의 파일 이름(그때 이름은 Workspaces). 같은 폴더에 있다.
    public static let legacyFileName = "Workspaces.json"

    /// 새 파일이 아직 없고 예전 `Workspaces.json`이 있으면 이름만 바꿔 옮긴다(내용 형식은 같다).
    /// 옮기지 못하면 예전 파일을 그대로 읽는다. 원본은 지우지 않는다(이동이 곧 보존이다).
    private var readableFileURL: URL {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: fileURL.path) else { return fileURL }
        let legacy = fileURL.deletingLastPathComponent()
            .appendingPathComponent(Self.legacyFileName)
        guard fm.fileExists(atPath: legacy.path) else { return fileURL }
        do {
            try fm.moveItem(at: legacy, to: fileURL)
            return fileURL
        } catch {
            return legacy
        }
    }

    public func load() -> [ChapLayout] {
        let source = readableFileURL
        guard source == fileURL else {
            // 옮기지 못한 예전 파일: 읽기만 한다. 다음 저장이 새 파일을 만든다.
            guard let data = try? Data(contentsOf: source),
                let decoded = try? JSONDecoder().decode([ChapLayout].self, from: data)
            else { return [] }
            return Self.normalized(decoded)
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        guard let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([ChapLayout].self, from: data)
        else {
            preserveUnreadableFile()
            return []
        }
        return Self.normalized(decoded)
    }

    public func save(_ layouts: [ChapLayout]) throws {
        try refuseToOverwriteUnreadableFile()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Self.normalized(layouts)).write(to: fileURL, options: .atomic)
    }

    public static func cleanedName(_ raw: String) -> String? {
        let oneLine = raw.components(separatedBy: .newlines).joined(separator: " ")
        let trimmed = oneLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > maxNameLength ? String(trimmed.prefix(maxNameLength)) : trimmed
    }

    public static func adding(
        name: String, windows: [LayoutWindow], to layouts: [ChapLayout]
    ) -> [ChapLayout] {
        guard layouts.count < maxLayouts, let name = cleanedName(name), !windows.isEmpty
        else { return layouts }
        return layouts
            + [ChapLayout(name: name, windows: Array(windows.prefix(maxWindows)))]
    }

    /// 저장된 Layout을 고친다(이름·창·디스플레이). 자리와 id는 그대로 둔다.
    /// 이름이 비거나 창이 하나도 없으면 그대로 돌려준다(지우기는 `removing`).
    public static func replacing(
        _ id: UUID, name: String, windows: [LayoutWindow], in layouts: [ChapLayout]
    ) -> [ChapLayout] {
        guard let name = cleanedName(name), !windows.isEmpty else { return layouts }
        return layouts.map { layout in
            guard layout.id == id else { return layout }
            return ChapLayout(
                id: layout.id, name: name, windows: Array(windows.prefix(maxWindows)))
        }
    }

    public static func removing(_ id: UUID, from layouts: [ChapLayout]) -> [ChapLayout] {
        layouts.filter { $0.id != id }
    }

    private func preserveUnreadableFile() {
        let timestamp = Int(Date().timeIntervalSince1970)
        let name = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        let backupName = "\(name).unreadable-\(timestamp)" + (ext.isEmpty ? "" : ".\(ext)")
        let destination = fileURL.deletingLastPathComponent().appendingPathComponent(backupName)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
    }

    private func refuseToOverwriteUnreadableFile() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL),
            (try? JSONDecoder().decode([ChapLayout].self, from: data)) != nil
        else { throw LayoutStoreError.unreadableExistingFile }
    }

    private static func normalized(_ layouts: [ChapLayout]) -> [ChapLayout] {
        layouts.prefix(maxLayouts).compactMap { layout in
            guard let name = cleanedName(layout.name), !layout.windows.isEmpty else {
                return nil
            }
            return ChapLayout(
                id: layout.id, name: name,
                windows: Array(layout.windows.prefix(maxWindows)))
        }
    }
}

public enum LayoutStoreError: LocalizedError, Equatable {
    case unreadableExistingFile

    public var errorDescription: String? {
        "The existing Layouts file could not be read, so Chap left it untouched."
    }
}
