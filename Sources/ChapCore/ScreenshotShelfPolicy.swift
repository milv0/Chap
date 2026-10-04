import Foundation

/// 노치 패널 왼쪽 칸에 모이는 스크린샷 선반의 선택 규칙.
/// 파일 시스템 접근과 분리된 순수 정책이라 단위 테스트로 고정한다.
public enum ScreenshotShelfPolicy {
    /// 선반에 담는 최대 파일 수. 한 번에 4줄이 보이고 나머지는 스크롤로 본다.
    public static let maxItems = 12
    /// 스크롤 없이 보이는 줄 수. 노치 목록 칸 4줄과 같다.
    public static let visibleRows = 4

    /// 스크린샷으로 취급하는 이미지 확장자.
    public static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "tiff", "gif",
    ]

    /// 숨김 파일이 아니고 이미지 확장자인 파일만 선반 후보다.
    public static func isCandidate(fileName: String) -> Bool {
        guard !fileName.hasPrefix(".") else { return false }
        let ext = (fileName as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    /// 후보만 남겨 수정 시각 최신순으로 정렬하고 최대 개수로 자른다.
    public static func shelfSelection(files: [(name: String, modified: Date)]) -> [String] {
        files
            .filter { isCandidate(fileName: $0.name) }
            .sorted { $0.modified > $1.modified }
            .prefix(maxItems)
            .map(\.name)
    }

    /// 선반 행의 짧은 시각 문구. 잘린 파일명 대신 언제 찍었는지를 보여준다.
    public static func relativeLabel(for date: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 { return "Just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60)) min ago" }
        let calendar = Calendar(identifier: .gregorian)
        if calendar.isDate(date, inSameDayAs: now) {
            let hours = Int(elapsed / 3600)
            return hours == 1 ? "1 hr ago" : "\(hours) hr ago"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
