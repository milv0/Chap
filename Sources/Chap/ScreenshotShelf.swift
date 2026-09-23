import AppKit

/// 스크린샷 선반의 파일 소스. macOS 스크린샷 저장 위치를 읽어
/// 정책(`ScreenshotShelfPolicy`)이 고른 최신 파일들을 돌려준다.
enum ScreenshotShelf {
    /// 시스템 스크린샷 저장 폴더. 사용자가 바꾼 위치
    /// (`com.apple.screencapture location`)를 존중하고, 없으면 데스크톱.
    static func directory() -> URL {
        let defaults = UserDefaults(suiteName: "com.apple.screencapture")
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

    /// 폴더를 스캔해 정책이 고른 최신 스크린샷 URL을 최신순으로 돌려준다.
    static func recentScreenshots() -> [URL] {
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
        let selected = ScreenshotShelfPolicy.shelfSelection(files: files)
        return selected.map { folder.appendingPathComponent($0) }
    }
}
