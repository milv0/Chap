import AppKit

/// 스크린샷 선반의 파일 소스. macOS 스크린샷 저장 위치를 읽어
/// 정책(`ScreenshotShelfPolicy`)이 고른 최신 파일들을 돌려준다.
enum ScreenshotShelf {
    /// 오프스크린 렌더 도구 전용: 설정하면 노치가 파일을 읽는 대신 이 목록을 첫 프레임에 쓴다.
    /// 앱 실행 중에는 항상 nil이다.
    static var previewOverride: [URL]?
    /// 마지막으로 확인한 "스크린샷 없음" 여부. 노치를 열 때 이 값으로 시작해, 열자마자 칸이 접히며
    /// 도커가 줄어드는 움직임이 생기지 않게 한다. 렌더 도구는 `previewOverride`가 우선한다.
    static var lastKnownEmpty = false
    static var initiallyEmpty: Bool { previewOverride.map(\.isEmpty) ?? lastKnownEmpty }
    /// 마지막으로 읽은 가장 새 스크린샷 시각과, 저절로 펼친 칸을 사용자가 다시 접었을 때의 시각(메모리에만).
    /// 접어 둔 칸을 10분 안의 스크린샷 때문에 펼칠지 첫 프레임에서 정한다(`DownloadsShelf`와 같은 규칙).
    static var lastKnownNewest: Date?
    static var dismissedNewest: Date?
    static var initiallyRecent: Bool {
        previewOverride == nil
            && ShelfAutoCollapsePolicy.expandsForRecent(
                newest: lastKnownNewest, dismissed: dismissedNewest, now: Date())
    }

    private static let ioQueue = DispatchQueue(
        label: "com.mingyupark.Chap.screenshots", qos: .utility,
        attributes: .concurrent)

    private static let screencaptureDomain = "com.apple.screencapture"
    private static let screenshotAppBundleID = "com.apple.screenshot.launcher"

    /// macOS 스크린샷 앱(⌘⇧5와 같은 화면)을 연다. 저장 위치는 사용자가 앱의 Options → Other Location…에서
    /// 직접 바꾼다. Chap은 시스템 설정 값을 쓰지 않는다.
    @discardableResult
    static func openScreenshotApp() -> Bool {
        guard
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: screenshotAppBundleID)
        else { return false }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
        return true
    }

    /// 시스템 스크린샷 저장 폴더. 사용자가 바꾼 위치
    /// (`com.apple.screencapture location`)를 존중하고, 없으면 데스크톱.
    static func directory() -> URL {
        // 스크린샷 앱에서 위치를 바꾼 직후에도 새 값을 읽도록 캐시를 맞춘다. 읽기만 하고 쓰지 않는다.
        CFPreferencesAppSynchronize(screencaptureDomain as CFString)
        let defaults = UserDefaults(suiteName: screencaptureDomain)
        if let location = defaults?.string(forKey: "location"), !location.isEmpty {
            let expanded = (location as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory),
                isDirectory.boolValue
            {
                return URL(fileURLWithPath: expanded, isDirectory: true)
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
    }

    /// 폴더 스캔과 per-file stat을 utility queue에서 수행한다.
    static func recentScreenshotsAsync(completion: @escaping ([URL]) -> Void) {
        ioQueue.async {
            let scan = recentScreenshotsSynchronously()
            DispatchQueue.main.async {
                lastKnownNewest = scan.newest
                completion(scan.files)
            }
        }
    }

    private static func recentScreenshotsSynchronously() -> (files: [URL], newest: Date?) {
        let folder = directory()
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])
        else { return ([], nil) }

        let files = entries.map { url in
            (
                name: url.lastPathComponent,
                modified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
            )
        }
        let selected = ScreenshotShelfPolicy.shelfSelection(files: files)
        return (
            selected.map { folder.appendingPathComponent($0) },
            ScreenshotShelfPolicy.newestDate(files: files)
        )
    }
}
