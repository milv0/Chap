import AppKit
import Foundation

public func isValidDomain(_ domain: String) -> Bool {
    guard !domain.isEmpty,
        let regex = Defaults.domainRegex,
        regex.firstMatch(in: domain, range: NSRange(domain.startIndex..., in: domain)) != nil
    else { return false }
    return true
}

public var cursorScreen: NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        ?? NSScreen.main
        ?? NSScreen.screens.first ?? NSScreen.main!
}

public func targetScreen(for site: Site) -> NSScreen {
    if let name = site.displayName {
        return NSScreen.screens.first { $0.localizedName == name }
            ?? NSScreen.main
            ?? NSScreen.screens.first ?? NSScreen.main!
    }
    return cursorScreen
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
