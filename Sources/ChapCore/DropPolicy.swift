import Foundation

/// Chap Drop(드롭 존)에 보여줄 파일의 선택 규칙.
/// 스크린샷 선반과 달리 모든 파일 종류를 받는다.
public enum DropPolicy {
    /// 선반에 보여줄 최대 파일 수. 노치 위젯 칸 상한과 통일한다.
    public static let maxItems = 4

    /// 숨김 파일만 제외하고 모든 파일이 후보다.
    public static func isCandidate(fileName: String) -> Bool {
        !fileName.hasPrefix(".")
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
