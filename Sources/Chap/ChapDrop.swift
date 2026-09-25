import AppKit

/// Chap Drop 보관함. 떨어뜨린 파일을 Chap 고유 폴더에 복사해 두고,
/// 노치 패널에서 최신 파일을 꺼내 쓸 수 있게 한다.
///
/// 위치: `~/Library/Application Support/Chap/Drop/`
/// 접근은 노치 UI를 통해서만 이뤄지는 앱 내부 보관함 모델이다.
enum ChapDrop {
    /// 보관함 내용이 바뀔 때마다 게시된다. 배지 갱신 트리거.
    static let didChangeNotification = Notification.Name("ChapDropDidChange")

    /// 보관함의 전체 파일 수 (표시 상한과 무관한 실제 개수).
    static func fileCount() -> Int {
        let folder = directory()
        let entries =
            (try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])) ?? []
        return entries.filter { DropPolicy.isCandidate(fileName: $0.lastPathComponent) }
            .count
    }

    /// 보관함 폴더. 없으면 만든다.
    static func directory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let shelf =
            base
            .appendingPathComponent("Chap", isDirectory: true)
            .appendingPathComponent("Drop", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: shelf, withIntermediateDirectories: true)
        return shelf
    }

    /// 폴더를 스캔해 정책이 고른 최신 파일 URL을 최신순으로 돌려준다.
    static func recentFiles() -> [URL] {
        let folder = directory()
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])
        else { return [] }

        let files = entries.map { url in
            (
                name: url.lastPathComponent,
                modified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
            )
        }
        let selected = DropPolicy.shelfSelection(files: files)
        return selected.map { folder.appendingPathComponent($0) }
    }

    /// 드롭된 파일을 보관함으로 복사한다. 이름이 겹치면 " 2", " 3"…을 붙인다.
    /// 복사 성공한 보관함 내 URL 목록을 돌려준다.
    @discardableResult
    static func store(_ urls: [URL]) -> [URL] {
        let folder = directory()
        var stored: [URL] = []
        for source in urls {
            let destination = availableDestination(
                for: source.lastPathComponent, in: folder)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                stored.append(destination)
            } catch {
                Log.config.error(
                    "Drop shelf copy failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if !stored.isEmpty {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
        return stored
    }

    /// 보관함에서 파일을 삭제한다.
    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// 겹치지 않는 대상 경로를 찾는다.
    private static func availableDestination(for name: String, in folder: URL) -> URL {
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
