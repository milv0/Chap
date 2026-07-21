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
public func appKitFrame(fromTopLeft bounds: (left: Int, top: Int, right: Int, bottom: Int))
    -> NSRect
{
    let primaryH = NSScreen.screens.first?.frame.height ?? 0
    let width = CGFloat(bounds.right - bounds.left)
    let height = CGFloat(bounds.bottom - bounds.top)
    return NSRect(
        x: CGFloat(bounds.left),
        y: primaryH - CGFloat(bounds.top) - height,
        width: width,
        height: height)
}

/// Scales a requested window size down to fit a screen's visible area while
/// preserving its aspect ratio. NSScreen frame values are AppKit points, not
/// physical pixels, so Retina displays can have smaller usable sizes than
/// names like "Full HD" imply.
public func fittedWindowSize(width: Int, height: Int, on screen: NSScreen) -> (
    width: Int, height: Int
) {
    let requestedWidth = max(100, width)
    let requestedHeight = max(100, height)
    let maxWidth = max(100, Int(screen.visibleFrame.width))
    let maxHeight = max(100, Int(screen.visibleFrame.height))
    let scale = min(
        1.0,
        CGFloat(maxWidth) / CGFloat(requestedWidth),
        CGFloat(maxHeight) / CGFloat(requestedHeight)
    )
    return (
        max(100, Int((CGFloat(requestedWidth) * scale).rounded(.down))),
        max(100, Int((CGFloat(requestedHeight) * scale).rounded(.down)))
    )
}

/// Calculate AppleScript-compatible bounds (top-left origin) for centering a window on a given screen.
/// NSScreen uses bottom-left AppKit screen coordinates; AX/AppleScript bounds use top-left coordinates.
/// The primary screen (screens[0]) defines the global coordinate origin.
///
/// The window is fitted and centered in `visibleFrame`, matching AppKit's
/// documented visible screen rect that excludes the menu bar and Dock.
public func centeredBounds(for site: Site, on screen: NSScreen) -> (
    left: Int, top: Int, right: Int, bottom: Int
) {
    let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
    let visibleFrame = screen.visibleFrame
    let fittedSize = fittedWindowSize(width: site.width, height: site.height, on: screen)
    let bw = fittedSize.width
    let bh = fittedSize.height
    let bx = Int(visibleFrame.minX + (visibleFrame.width - CGFloat(bw)) / 2)
    let by = Int(primaryH - visibleFrame.maxY + (visibleFrame.height - CGFloat(bh)) / 2)
    return (bx, by, bx + bw, by + bh)
}
