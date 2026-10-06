import Foundation

/// 노치 다운로드 선반이 ~/Downloads에서 보여줄 파일을 고르는 규칙.
/// 파일 시스템 접근과 분리된 순수 정책이라 단위 테스트로 고정한다.
public enum DownloadsShelfPolicy {
    /// 선반에 담는 최대 파일 수. 한 번에 4줄이 보이고 나머지는 스크롤로 본다.
    public static let maxItems = 12
    /// 스크롤 없이 보이는 줄 수. 다른 목록 칸과 같은 4줄.
    public static let visibleRows = 4

    /// 줄에 마우스를 올린 뒤 전체 파일명 말풍선이 뜨기까지의 지연(초). 목록을 훑을 때 깜빡이지 않는다.
    public static let fullNameRevealDelay: Double = 0.35
    /// 전체 파일명 말풍선의 최대 폭(pt). 넘으면 두 줄까지 감싼다.
    public static let fullNameMaxWidth: Double = 320

    /// 파일명이 줄 안에서 잘려 보일 때만 전체 이름을 띄운다. 0.5pt 여유는 반올림 오차를 흡수한다.
    public static func needsFullName(idealWidth: Double, shownWidth: Double) -> Bool {
        idealWidth > shownWidth + 0.5
    }

    /// 아직 받는 중인 파일의 확장자 (Chrome, Safari, Firefox, 일반 부분 파일).
    public static let inProgressExtensions: Set<String> = [
        "crdownload", "download", "part", "partial", "opdownload", "tmp",
    ]

    /// 숨김 파일, 받는 중인 파일, 폴더(.app 번들 제외)는 뺀다.
    public static func isCandidate(fileName: String, isDirectory: Bool) -> Bool {
        guard !fileName.hasPrefix(".") else { return false }
        let ext = (fileName as NSString).pathExtension.lowercased()
        if inProgressExtensions.contains(ext) { return false }
        if isDirectory { return ext == "app" }
        return true
    }

    /// 후보만 남겨 최근 순(받은 시각, 없으면 수정 시각)으로 정렬하고 최대 개수로 자른다.
    public static func shelfSelection(
        files: [(name: String, isDirectory: Bool, date: Date)]
    ) -> [String] {
        files
            .filter { isCandidate(fileName: $0.name, isDirectory: $0.isDirectory) }
            .sorted { $0.date > $1.date }
            .prefix(maxItems)
            .map(\.name)
    }

    /// 한 칸 오른쪽에 맞는 아주 짧은 시각. 파일명에 폭을 더 주려고 "min ago" 대신 "5m", 어제는 "1d"를 쓴다.
    public static func shortAge(of date: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 { return "now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m" }
        let calendar = Calendar(identifier: .gregorian)
        if calendar.isDate(date, inSameDayAs: now) { return "\(Int(elapsed / 3600))h" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "1d"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
