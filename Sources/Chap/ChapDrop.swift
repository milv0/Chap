import AppKit

/// Chap Drop 보관함. 떨어뜨린 파일을 Chap 고유 폴더에 복사해 두고,
/// 노치 패널에서 최신 파일을 꺼내 쓸 수 있게 한다.
///
/// 위치: `~/Library/Application Support/Chap/Drop/`
/// 접근은 노치 UI를 통해서만 이뤄지는 앱 내부 보관함 모델이다.
enum ChapDrop {
    /// 보관함 내용이 바뀔 때마다 메인 큐에서 게시된다. 배지·파일 행 갱신 트리거.
    static let didChangeNotification = Notification.Name("ChapDropDidChange")

    /// 직렬 queue라 동일 이름 파일을 동시에 드롭해도 destination 선택과 copy가
    /// 경쟁하지 않으며, 큰 파일/폴더 복사가 메인 런루프를 막지 않는다.
    private static let ioQueue = DispatchQueue(
        label: "com.mingyupark.Chap.drop", qos: .utility)

    /// 보관함 폴더. 없으면 만든다.
    static func directory() -> URL {
        let manager = FileManager.default
        let base =
            manager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
            ?? manager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        let drop =
            base
            .appendingPathComponent("Chap", isDirectory: true)
            .appendingPathComponent("Drop", isDirectory: true)
        do {
            try manager.createDirectory(at: drop, withIntermediateDirectories: true)
        } catch {
            Log.config.error(
                "Drop directory creation failed: \(error.localizedDescription, privacy: .public)")
        }
        return drop
    }

    /// 보관함의 전체 파일 수를 background queue에서 센다.
    static func fileCountAsync(completion: @escaping (Int) -> Void) {
        ioQueue.async {
            let count = fileCountSynchronously()
            DispatchQueue.main.async { completion(count) }
        }
    }

    /// 최신 파일 목록을 background queue에서 읽는다.
    static func recentFilesAsync(
        limit: Int = DropPolicy.maxItems,
        completion: @escaping ([URL]) -> Void
    ) {
        ioQueue.async {
            let files = recentFilesSynchronously(limit: limit)
            DispatchQueue.main.async { completion(files) }
        }
    }

    /// 드롭된 파일을 background queue에서 직렬 복사한다. 이름이 겹치면
    /// " 2", " 3"…을 붙인다. completion은 메인 큐에서 성공 URL과 실패 수를 받는다.
    static func storeAsync(
        _ urls: [URL], completion: @escaping (_ stored: [URL], _ failedCount: Int) -> Void
    ) {
        ioQueue.async {
            let folder = directory()
            var stored: [URL] = []
            var failedCount = 0
            for source in urls {
                let destination = availableDestination(
                    for: source.lastPathComponent, in: folder)
                do {
                    try FileManager.default.copyItem(at: source, to: destination)
                    stored.append(destination)
                } catch {
                    failedCount += 1
                    Log.config.error(
                        "Chap Drop copy failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            DispatchQueue.main.async {
                if !stored.isEmpty {
                    NotificationCenter.default.post(name: didChangeNotification, object: nil)
                }
                completion(stored, failedCount)
            }
        }
    }

    /// 보관함 파일을 background queue에서 삭제한다.
    static func removeAsync(_ url: URL, completion: @escaping (Bool) -> Void) {
        ioQueue.async {
            let removed: Bool
            do {
                try FileManager.default.removeItem(at: url)
                removed = true
            } catch {
                removed = false
                Log.config.error(
                    "Chap Drop remove failed: \(error.localizedDescription, privacy: .public)")
            }
            DispatchQueue.main.async {
                if removed {
                    NotificationCenter.default.post(name: didChangeNotification, object: nil)
                }
                completion(removed)
            }
        }
    }

    // MARK: - Synchronous helpers (ioQueue only)

    private static func fileCountSynchronously() -> Int {
        let entries =
            (try? FileManager.default.contentsOfDirectory(
                at: directory(), includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])) ?? []
        return entries.filter { DropPolicy.isCandidate(fileName: $0.lastPathComponent) }.count
    }

    private static func recentFilesSynchronously(limit: Int) -> [URL] {
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
        let selected = DropPolicy.shelfSelection(files: files, limit: limit)
        return selected.map { folder.appendingPathComponent($0) }
    }

    /// ioQueue가 호출을 직렬화하므로 fileExists→copy 사이에 내부 경쟁이 없다.
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
