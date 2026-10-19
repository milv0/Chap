import AppKit

/// 다운로드 선반의 파일 소스. ~/Downloads를 읽어 정책(`DownloadsShelfPolicy`)이 고른
/// 최신 파일을 돌려준다. 원본은 옮기거나 복제하지 않는다.
///
/// Chap은 샌드박스 앱이 아니지만, macOS가 다운로드 폴더를 보호하므로 이 위젯을 처음 쓸 때
/// "다운로드 폴더 접근" 권한을 한 번 묻는다. Downloads 칸이 노치에 놓여 있을 때만 읽는다
/// (접혀 있어도 최근 다운로드를 보고 칸을 펼칠지 정하려고 읽는다).
enum DownloadsShelf {
    /// 오프스크린 렌더 도구 전용: 설정하면 노치가 파일을 읽는 대신 이 목록을 첫 프레임에 쓴다.
    static var previewOverride: [URL]?
    /// (렌더 도구) 마우스를 올린 것처럼 전체 파일명 말풍선을 띄울 파일.
    static var previewHoveredURL: URL?

    /// 마지막으로 읽은 가장 새 다운로드 시각(메인 스레드 전용, 메모리에만). 도커를 열 때 첫 프레임에서
    /// 접어 둔 칸을 펼칠지 이것으로 정해, 열자마자 폭이 바뀌지 않게 한다.
    static var lastKnownNewest: Date?
    /// 저절로 펼쳐진 칸을 사용자가 다시 접었을 때의 가장 새 시각(메모리에만).
    static var dismissedNewest: Date?

    /// 지금 알고 있는 값으로, 접어 둔 Downloads 칸을 이번에 펼칠지.
    static var initiallyRecent: Bool {
        ShelfAutoCollapsePolicy.expandsDownloads(
            newest: lastKnownNewest, dismissed: dismissedNewest, now: Date())
    }

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
            let scan = scanSynchronously()
            DispatchQueue.main.async {
                lastKnownNewest = scan.newest
                completion(scan.files)
            }
        }
    }

    /// 가장 새 다운로드 시각만 읽는다(칸이 접혀 있을 때). `lastKnownNewest`도 갱신한다.
    static func newestDownloadAsync(completion: @escaping (Date?) -> Void) {
        ioQueue.async {
            let newest = scanSynchronously().newest
            DispatchQueue.main.async {
                lastKnownNewest = newest
                completion(newest)
            }
        }
    }

    private static func scanSynchronously() -> (files: [URL], newest: Date?) {
        let folder = directory()
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .addedToDirectoryDateKey, .contentModificationDateKey,
        ]
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        else { return ([], nil) }

        let files = entries.map { url -> (name: String, isDirectory: Bool, date: Date) in
            let values = try? url.resourceValues(forKeys: Set(keys))
            // 받은 순서가 중요하다: 폴더에 들어온 시각을 먼저 쓴다.
            let date =
                values?.addedToDirectoryDate ?? values?.contentModificationDate ?? .distantPast
            return (url.lastPathComponent, values?.isDirectory ?? false, date)
        }
        let selection = DownloadsShelfPolicy.shelfSelection(files: files)
            .map { folder.appendingPathComponent($0) }
        return (selection, DownloadsShelfPolicy.newestDate(files: files))
    }

    /// 파일이 폴더에 들어온 시각. 없으면 수정 시각.
    static func addedDate(of url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [
            .addedToDirectoryDateKey, .contentModificationDateKey,
        ])
        return values?.addedToDirectoryDate ?? values?.contentModificationDate
    }
}
