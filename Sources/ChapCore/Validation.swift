import AppKit
import Foundation

public func isValidDomain(_ domain: String) -> Bool {
    guard !domain.isEmpty,
        let regex = Defaults.domainRegex,
        regex.firstMatch(in: domain, range: NSRange(domain.startIndex..., in: domain)) != nil
    else { return false }
    return true
}

/// 커서가 위치한 화면. 사용 가능한 화면이 하나도 없으면 nil.
public var cursorScreen: NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        ?? NSScreen.main
        ?? NSScreen.screens.first
}

/// 사이트가 열릴 대상 화면. 지정된 displayName이 없거나 매칭 화면이 없으면
/// 커서 화면으로, 그마저 없으면 nil로 폴백.
public func targetScreen(for site: Site) -> NSScreen? {
    if let name = site.displayName {
        return NSScreen.screens.first { $0.localizedName == name }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
    return cursorScreen
}

/// 좌상단 원점(AppleScript/글로벌) 좌표계의 bounds를
/// NSWindow 배치에 쓰는 좌하단 원점 NSRect로 변환한다.
/// 주 화면(screens[0])이 글로벌 원점을 정의한다.
public func appKitFrame(fromTopLeft bounds: (left: Int, top: Int, right: Int, bottom: Int)) -> NSRect {
    let primaryH = NSScreen.screens.first?.frame.height ?? 0
    let width = CGFloat(bounds.right - bounds.left)
    let height = CGFloat(bounds.bottom - bounds.top)
    return NSRect(
        x: CGFloat(bounds.left),
        y: primaryH - CGFloat(bounds.top) - height,
        width: width,
        height: height)
}

/// Calculate AppleScript-compatible bounds (top-left origin) for centering a window on a given screen.
/// macOS NSScreen uses bottom-left origin; AppleScript uses top-left origin.
/// The primary screen (screens[0]) defines the global coordinate origin.
///
/// Width/height are clamped to the target screen's visibleFrame so the centered
/// window fully fits within that screen. Without clamping, a too-tall window
/// produces a negative `top` which macOS interprets as belonging to the screen
/// above (e.g. an external monitor stacked above the built-in display), causing
/// the window to launch on the wrong display.
public func centeredBounds(for site: Site, on screen: NSScreen) -> (
    left: Int, top: Int, right: Int, bottom: Int
) {
    let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
    let origin = screen.frame.origin
    let screenOffsetX = Int(origin.x)
    let screenOffsetY = Int(primaryH - origin.y - screen.frame.height)
    let visW = Int(screen.visibleFrame.width)
    let visH = Int(screen.visibleFrame.height)
    let bw = min(site.width, visW)
    let bh = min(site.height, visH)
    let bx = screenOffsetX + (Int(screen.frame.width) - bw) / 2
    let by = screenOffsetY + (Int(screen.frame.height) - bh) / 2
    return (bx, by, bx + bw, by + bh)
}
