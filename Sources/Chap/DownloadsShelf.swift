import AppKit

/// 다운로드 선반의 파일 소스. ~/Downloads를 읽어 정책(`DownloadsShelfPolicy`)이 고른
/// 최신 파일을 돌려준다. 원본은 옮기거나 복제하지 않는다.
///
/// Chap은 샌드박스 앱이 아니지만, macOS가 다운로드 폴더를 보호하므로 이 위젯을 처음 쓸 때
/// "다운로드 폴더 접근" 권한을 한 번 묻는다. 위젯이 노치에 보일 때만 읽는다.
enum DownloadsShelf {
    /// 오프스크린 렌더 도구 전용: 설정하면 노치가 파일을 읽는 대신 이 목록을 첫 프레임에 쓴다.
    static var previewOverride: [URL]?
    /// (렌더 도구) 마우스를 올린 것처럼 전체 파일명 말풍선을 띄울 파일.
    static var previewHoveredURL: URL?

    private static let ioQueue = DispatchQueue(
        label: "com.mingyupark.Chap.downloads", qos: .utility)

    static func directory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    /// 폴더 스캔과 파일별 stat을 utility queue에서 수행한다.
    static func recentFilesAsync(completion: @escaping ([URL]) -> Void) {
        ioQueue.async {
            let files = recentFilesSynchronously()
            DispatchQueue.main.async { completion(files) }
        }
    }

    private static func recentFilesSynchronously() -> [URL] {
        let folder = directory()
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .addedToDirectoryDateKey, .contentModificationDateKey,
        ]
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        else { return [] }

        let files = entries.map { url -> (name: String, isDirectory: Bool, date: Date) in
            let values = try? url.resourceValues(forKeys: Set(keys))
            // 받은 순서가 중요하다: 폴더에 들어온 시각을 먼저 쓴다.
            let date =
                values?.addedToDirectoryDate ?? values?.contentModificationDate ?? .distantPast
            return (url.lastPathComponent, values?.isDirectory ?? false, date)
        }
        return DownloadsShelfPolicy.shelfSelection(files: files)
            .map { folder.appendingPathComponent($0) }
    }

    /// 파일이 폴더에 들어온 시각. 없으면 수정 시각.
    static func addedDate(of url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [
            .addedToDirectoryDateKey, .contentModificationDateKey,
        ])
        return values?.addedToDirectoryDate ?? values?.contentModificationDate
    }
}
