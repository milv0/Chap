/// AppKit이 메뉴를 추적하는 동안 root menu 교체를 막고 여러 요청을 한 번으로 합친다.
struct MenuRebuildGate {
    private(set) var isTracking = false
    private var hasPendingRebuild = false

    mutating func didOpen() {
        isTracking = true
    }

    /// 지금 바로 다시 만들어도 되면 true. 메뉴 추적 중이면 요청만 기억한다.
    mutating func request() -> Bool {
        guard !isTracking else {
            hasPendingRebuild = true
            return false
        }
        return true
    }

    /// 닫힌 뒤 다시 만들어야 하면 true. 누적 요청은 한 번에 소비한다.
    mutating func didClose() -> Bool {
        isTracking = false
        defer { hasPendingRebuild = false }
        return hasPendingRebuild
    }
}
