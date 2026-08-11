import AppKit
import Foundation

/// 커서가 위치한 화면. 사용 가능한 화면이 하나도 없으면 nil.
public var cursorScreen: NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        ?? NSScreen.main
        ?? NSScreen.screens.first
}

/// 내장 디스플레이. Follow Cursor 프리셋 크기 기준으로 사용한다.
public var builtInScreen: NSScreen? {
    NSScreen.screens.first { screen in
        guard
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID
        else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }
}

/// 저장된 사이트가 Follow Cursor가 아닌 특정 디스플레이를 가리키는지 확인한다.
public func hasExplicitDisplaySelection(_ site: Site) -> Bool {
    let identifier = site.displayIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let name = site.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !identifier.isEmpty || !name.isEmpty
}

/// 사이트가 열릴 대상 화면. displayIdentifier(UUID) → displayName 순으로 매칭하고,
/// 둘 다 실패하거나 지정이 없으면(Follow Cursor) 커서 화면으로 폴백. 커서 화면도 없으면 nil.
public func targetScreen(for site: Site) -> NSScreen? {
    let screens = NSScreen.screens
    let candidates = screens.map {
        DisplayMatchCandidate(identifier: displayUUID(for: $0), name: $0.localizedName)
    }
    if let index = resolvedDisplayIndex(
        displayIdentifier: site.displayIdentifier,
        displayName: site.displayName,
        among: candidates)
    {
        return screens[index]
    }
    return cursorScreen
}

/// 디스플레이 매칭에 필요한 최소 정보(순수 로직 테스트용).
public struct DisplayMatchCandidate: Equatable {
    public let identifier: String?
    public let name: String
    public init(identifier: String?, name: String) {
        self.identifier = identifier
        self.name = name
    }
}

/// 저장된 식별자/이름과 현재 연결된 디스플레이 목록으로 대상 인덱스를 결정한다.
/// UUID 완전 일치를 최우선으로 하여 동일 이름(같은 모델) 모니터도 정확히 구분하고,
/// UUID가 없거나(구버전 config) 매칭 실패 시 이름으로 폴백한다. 아무것도 못 맞추면 nil.
public func resolvedDisplayIndex(
    displayIdentifier: String?, displayName: String?, among displays: [DisplayMatchCandidate]
) -> Int? {
    if let id = displayIdentifier, !id.isEmpty,
        let index = displays.firstIndex(where: { $0.identifier == id })
    {
        return index
    }
    if let name = displayName, !name.isEmpty {
        let matchingIndices = displays.indices.filter { displays[$0].name == name }
        if matchingIndices.count == 1 {
            return matchingIndices[0]
        }
    }
    return nil
}

public func displaySizeOverrideIndex(
    displayIdentifier: String?, displayName: String?, among overrides: [DisplaySizeOverride]
) -> Int? {
    let candidates = overrides.map {
        DisplayMatchCandidate(identifier: $0.displayIdentifier, name: $0.displayName ?? "")
    }
    return resolvedDisplayIndex(
        displayIdentifier: displayIdentifier, displayName: displayName, among: candidates)
}

public func displaySizeOverride(for site: Site, on screen: NSScreen) -> DisplaySizeOverride? {
    guard
        let index = displaySizeOverrideIndex(
            displayIdentifier: displayUUID(for: screen),
            displayName: screen.localizedName,
            among: site.displaySizeOverrides)
    else { return nil }
    return site.displaySizeOverrides[index]
}

/// NSScreen의 안정적 고유 식별자(CGDisplay UUID 문자열). 물리 디스플레이별로 다르며
/// 재연결·재부팅에도 대체로 유지된다. 동일 모델 외장 모니터 여러 대도 구분된다.
public func displayUUID(for screen: NSScreen) -> String? {
    guard
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            as? CGDirectDisplayID,
        let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
    else { return nil }
    return CFUUIDCreateString(nil, uuid) as String
}
