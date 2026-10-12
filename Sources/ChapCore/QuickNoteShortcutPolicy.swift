import Foundation

/// Quick Note 창을 여는 ⌥ 단축키의 규칙. 기본은 ⌥N.
/// 사이트 단축키가 먼저다: 같은 키를 사이트가 쓰고 있으면 Quick Note 단축키는 등록하지 않는다
/// (업데이트 뒤 사용자의 사이트 단축키가 갑자기 다른 일을 하지 않게).
public enum QuickNoteShortcutPolicy {
    /// 처음 쓰는 키.
    public static let defaultKey = "N"

    /// 입력을 저장할 키로: 앞뒤 공백을 지우고 첫 글자를 대문자로. 비면 nil(끔).
    public static func normalized(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
            let first = trimmed.first
        else { return nil }
        return String(first).uppercased()
    }

    /// 이 키를 Quick Note가 쓸 수 없는 이유. nil이면 쓸 수 있다.
    public enum Conflict: Equatable, Sendable {
        /// ⌥. ⌥, 처럼 Chap이 예약한 키.
        case reserved
        /// 이 이름의 사이트가 이미 쓰고 있다.
        case site(name: String)
        /// 다른 Chap 기능(예: Quick Note)이 이미 쓰고 있다.
        case feature(name: String)
    }

    /// - Parameter taken: 먼저 키를 가져간 다른 기능 (키, 기능 이름). 사이트 다음으로 우선한다.
    public static func conflict(
        for key: String?, sites: [Site], taken: [(key: String, name: String)] = []
    ) -> Conflict? {
        guard let key = normalized(key) else { return nil }
        if reservedShortcutKeys.contains(key) { return .reserved }
        if let site = sanitizedShortcuts(for: sites).first(where: {
            $0.shortcut?.uppercased() == key
        }) {
            return .site(name: site.name)
        }
        if let feature = taken.first(where: { normalized($0.key) == key }) {
            return .feature(name: feature.name)
        }
        return nil
    }

    /// 실제로 등록할 키. 노치 런처와 Quick Note 아이콘이 켜져 있고, 키가 있고, 겹치지 않을 때만.
    /// 노치를 쓰지 않는 사람에게서 ⌥N(키보드 배열에 따라 ˜ 등의 입력)을 가져가지 않는다.
    public static func registeredKey(
        shortcut: String?, notchLauncherEnabled: Bool, quickNoteEnabled: Bool, sites: [Site]
    ) -> String? {
        guard notchLauncherEnabled, quickNoteEnabled, let key = normalized(shortcut),
            conflict(for: key, sites: sites) == nil
        else { return nil }
        return key
    }

    /// 설정창에 보여 줄 한 줄 안내. 겹치지 않으면 nil.
    public static func conflictMessage(_ conflict: Conflict, key: String) -> String {
        switch conflict {
        case .reserved: return "⌥\(key) is reserved by Chap."
        case .site(let name): return "⌥\(key) already opens \(name). Pick another key."
        case .feature(let name): return "⌥\(key) already opens \(name). Pick another key."
        }
    }
}
