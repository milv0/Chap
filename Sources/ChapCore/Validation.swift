import Foundation

public func isValidDomain(_ domain: String) -> Bool {
    guard !domain.isEmpty,
        let regex = Defaults.domainRegex,
        regex.firstMatch(in: domain, range: NSRange(domain.startIndex..., in: domain)) != nil
    else { return false }
    return true
}

/// URL launch type이 저장/실행 가능한 HTTP(S) URL인지 확인한다.
public func isValidLaunchURL(_ urlString: String) -> Bool {
    launchURLHost(urlString) != nil
}

/// URL launch type이 사용할 host를 반환한다. 유효하지 않으면 nil.
public func launchURLHost(_ urlString: String) -> String? {
    let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let components = URLComponents(string: trimmedURL),
        let scheme = components.scheme?.lowercased(),
        scheme == "http" || scheme == "https",
        let host = components.host,
        isValidDomain(host)
    else {
        return nil
    }
    return host
}

/// Chap이 자체 글로벌 단축키로 예약한 키. 사이트가 가져갈 수 없다.
/// ⌥. → 메뉴 열기, ⌥, → 설정 열기.
public let reservedShortcutKeys: Set<String> = [".", ","]

/// 신뢰할 수 없는 소스(Import된 JSON, 손으로 편집한 ~/.chap.json)에서 온 사이트의
/// 단축키를 정규화한다. 설정 UI는 저장 시 이 규칙을 강제하지만 import/디스크 로드
/// 경로는 우회하므로, 두 경로에서 이 함수를 호출해 동일한 상태를 보장한다.
///
/// 규칙:
/// - 공백만 있거나 빈 단축키 → nil
/// - 한 글자가 아닌 단축키 → nil
/// - 예약키(".", ",") → nil
/// - 중복 단축키(대소문자 무시) → 앞의 것만 유지, 나머지는 nil
///
/// 저장된 대소문자 표기는 유지한다(메뉴 keyEquivalent가 그대로 사용).
public func sanitizedShortcuts(for sites: [Site]) -> [Site] {
    var seen = Set<String>()
    return sites.map { site in
        var sanitized = site
        guard let raw = site.shortcut else { return sanitized }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = key.uppercased()
        if key.count != 1 || reservedShortcutKeys.contains(key) || seen.contains(upper) {
            sanitized.shortcut = nil
        } else {
            seen.insert(upper)
            sanitized.shortcut = key
        }
        return sanitized
    }
}
