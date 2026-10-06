import AppKit

/// Chap Drop 보관함. 떨어뜨린 파일은 복사하지 않고 원본을 가리키는 북마크로 기억한다(`DropStore`).
/// 원본을 옮겨도 따라가고, 지우면 보관함에서도 사라진다. 임시 위치에서 온 파일만 사본을 둔다.
///
/// 위치: `~/Library/Application Support/Chap/Drop/` (참조 목록 `.references.json` + Chap 사본)
/// 접근은 노치 UI를 통해서만 이뤄지는 앱 내부 보관함 모델이다.
enum ChapDrop {
    /// 오프스크린 렌더 도구 전용: 설정하면 노치가 파일을 읽는 대신 이 목록을 첫 프레임에 쓴다.
    /// 앱 실행 중에는 항상 nil이다.
    static var previewOverride: [URL]?

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

    /// 드롭된 파일을 background queue에서 보관함에 넣는다(원본 참조, 임시 파일만 사본).
    /// completion은 메인 큐에서 넣은 URL과 실패 수를 받는다.
    static func storeAsync(
        _ urls: [URL], completion: @escaping (_ stored: [URL], _ failedCount: Int) -> Void
    ) {
        ioQueue.async {
            let result = store().add(urls)
            if result.failed > 0 {
                Log.config.error(
                    "Chap Drop could not keep \(result.failed, privacy: .public) item(s)")
            }
            DispatchQueue.main.async {
                if !result.stored.isEmpty {
                    NotificationCenter.default.post(name: didChangeNotification, object: nil)
                }
                completion(result.stored, result.failed)
            }
        }
    }

    /// 보관함에서 뺀다. 원본 참조는 목록에서만 지우고 원본 파일은 건드리지 않는다.
    static func removeAsync(_ url: URL, completion: @escaping (Bool) -> Void) {
        ioQueue.async {
            let removed = store().remove(url)
            if !removed {
                Log.config.error("Chap Drop remove failed for an item")
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

    private static func store() -> DropStore { DropStore(folder: directory()) }

    private static func fileCountSynchronously() -> Int {
        store().entries().count
    }

    private static func recentFilesSynchronously(limit: Int) -> [URL] {
        Array(store().entries().prefix(limit).map(\.url))
    }
}
