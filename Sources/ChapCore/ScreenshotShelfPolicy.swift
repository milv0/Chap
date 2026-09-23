import Foundation

/// 노치 패널 왼쪽 칸에 모이는 스크린샷 선반의 선택 규칙.
/// 파일 시스템 접근과 분리된 순수 정책이라 단위 테스트로 고정한다.
public enum ScreenshotShelfPolicy {
    /// 선반에 보여줄 최대 파일 수.
    public static let maxItems = 5

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
}
