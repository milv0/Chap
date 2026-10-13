import Foundation

/// Workspaces를 이 Mac에만 저장한다. Config import/export와 섞지 않는다.
public struct WorkspaceStore: Sendable {
    public static let maxWorkspaces = 4
    public static let maxWindows = 6
    public static let maxNameLength = 40

    public let fileURL: URL

    public init(fileURL: URL = WorkspaceStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Chap", isDirectory: true)
            .appendingPathComponent("Workspaces.json")
    }

    public func load() -> [ChapWorkspace] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        guard let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([ChapWorkspace].self, from: data)
        else {
            preserveUnreadableFile()
            return []
        }
        return Self.normalized(decoded)
    }

    public func save(_ workspaces: [ChapWorkspace]) throws {
        try refuseToOverwriteUnreadableFile()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Self.normalized(workspaces)).write(to: fileURL, options: .atomic)
    }

    public static func cleanedName(_ raw: String) -> String? {
        let oneLine = raw.components(separatedBy: .newlines).joined(separator: " ")
        let trimmed = oneLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > maxNameLength ? String(trimmed.prefix(maxNameLength)) : trimmed
    }

    public static func adding(
        name: String, windows: [WorkspaceWindow], to workspaces: [ChapWorkspace]
    ) -> [ChapWorkspace] {
        guard workspaces.count < maxWorkspaces, let name = cleanedName(name), !windows.isEmpty
        else { return workspaces }
        return workspaces
            + [ChapWorkspace(name: name, windows: Array(windows.prefix(maxWindows)))]
    }

    /// 저장된 Workspace를 고친다(이름·창·디스플레이). 자리와 id는 그대로 둔다.
    /// 이름이 비거나 창이 하나도 없으면 그대로 돌려준다(지우기는 `removing`).
    public static func replacing(
        _ id: UUID, name: String, windows: [WorkspaceWindow], in workspaces: [ChapWorkspace]
    ) -> [ChapWorkspace] {
        guard let name = cleanedName(name), !windows.isEmpty else { return workspaces }
        return workspaces.map { workspace in
            guard workspace.id == id else { return workspace }
            return ChapWorkspace(
                id: workspace.id, name: name, windows: Array(windows.prefix(maxWindows)))
        }
    }

    public static func removing(_ id: UUID, from workspaces: [ChapWorkspace]) -> [ChapWorkspace] {
        workspaces.filter { $0.id != id }
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
            (try? JSONDecoder().decode([ChapWorkspace].self, from: data)) != nil
        else { throw WorkspaceStoreError.unreadableExistingFile }
    }

    private static func normalized(_ workspaces: [ChapWorkspace]) -> [ChapWorkspace] {
        workspaces.prefix(maxWorkspaces).compactMap { workspace in
            guard let name = cleanedName(workspace.name), !workspace.windows.isEmpty else {
                return nil
            }
            return ChapWorkspace(
                id: workspace.id, name: name,
                windows: Array(workspace.windows.prefix(maxWindows)))
        }
    }
}

public enum WorkspaceStoreError: LocalizedError, Equatable {
    case unreadableExistingFile

    public var errorDescription: String? {
        "The existing Workspaces file could not be read, so Chap left it untouched."
    }
}
