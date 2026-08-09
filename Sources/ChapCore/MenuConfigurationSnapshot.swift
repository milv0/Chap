import Foundation

/// NSMenu 표시와 Carbon hotkey 등록에 실제로 영향을 주는 사이트 정보만 추린 스냅샷.
/// 크기·URL·디스플레이 변경은 메뉴/핫키 재구성을 유발하지 않는다.
struct MenuConfigurationSnapshot: Equatable {
    struct Entry: Equatable {
        let id: UUID
        let name: String
        let launchType: LaunchType
        let shortcut: String?
    }

    let entries: [Entry]

    init(sites: [Site]) {
        entries = sites.map {
            Entry(id: $0.id, name: $0.name, launchType: $0.launchType, shortcut: $0.shortcut)
        }
    }
}
