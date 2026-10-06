import Foundation

/// 비어 있는 선반을 저절로 접는 규칙. 저절로 접힌 상태는 저장하지 않는다(파일이 생기면 바로 펼쳐진다).
public enum ShelfAutoCollapsePolicy {
    /// 스크린샷이 하나도 없으면 Screenshots 칸을 검정 띠 왼쪽 아이콘으로 접는다.
    public static func collapsesScreenshots(count: Int) -> Bool {
        count == 0
    }
}
