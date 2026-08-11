import AppKit
import Foundation

/// 좌상단 원점(AppleScript/글로벌) 좌표계의 bounds를
/// NSWindow 배치에 쓰는 좌하단 원점 NSRect로 변환한다.
/// 주 화면(screens[0])이 글로벌 원점을 정의한다.
public func appKitFrame(fromTopLeft bounds: (left: Int, top: Int, right: Int, bottom: Int))
    -> NSRect
{
    appKitFrame(
        fromTopLeft: bounds,
        primaryHeight: NSScreen.screens.first?.frame.height ?? 0)
}

/// 좌표 변환 순수 코어(테스트 대상). primaryHeight는 주 화면 높이.
public func appKitFrame(
    fromTopLeft bounds: (left: Int, top: Int, right: Int, bottom: Int), primaryHeight: CGFloat
) -> NSRect {
    let width = CGFloat(bounds.right - bounds.left)
    let height = CGFloat(bounds.bottom - bounds.top)
    return NSRect(
        x: CGFloat(bounds.left),
        y: primaryHeight - CGFloat(bounds.top) - height,
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
    fittedSize(
        requestedWidth: width, requestedHeight: height,
        maxWidth: Int(screen.visibleFrame.width), maxHeight: Int(screen.visibleFrame.height))
}

/// 요청 크기를 최대 영역(maxWidth×maxHeight) 안에 종횡비를 유지한 채 축소하는 순수 코어.
/// 요청/최대 모두 최소 100pt로 클램프하며, 이미 들어맞으면 그대로 둔다.
public func fittedSize(requestedWidth: Int, requestedHeight: Int, maxWidth: Int, maxHeight: Int)
    -> (width: Int, height: Int)
{
    let rw = max(100, requestedWidth)
    let rh = max(100, requestedHeight)
    let mw = max(100, maxWidth)
    let mh = max(100, maxHeight)
    let scale = min(
        1.0,
        CGFloat(mw) / CGFloat(rw),
        CGFloat(mh) / CGFloat(rh)
    )
    return (
        max(100, Int((CGFloat(rw) * scale).rounded(.down))),
        max(100, Int((CGFloat(rh) * scale).rounded(.down)))
    )
}

public func windowSize(
    widthRatio: Double, heightRatio: Double, aspectRatio: Double?, on screen: NSScreen?
) -> (width: Int, height: Int) {
    guard let screen else {
        return (Defaults.defaultWidth, Defaults.defaultHeight)
    }
    return windowSizeFromRatio(
        widthRatio: widthRatio, heightRatio: heightRatio, aspectRatio: aspectRatio,
        visibleWidth: screen.visibleFrame.width, visibleHeight: screen.visibleFrame.height)
}

/// 화면 가시영역(visibleWidth×visibleHeight) 대비 비율로 창 크기를 구하는 순수 코어.
/// aspectRatio가 있으면 높이는 너비/비율로, 없으면 heightRatio로 계산한 뒤 가시영역에 맞춘다.
public func windowSizeFromRatio(
    widthRatio: Double, heightRatio: Double, aspectRatio: Double?,
    visibleWidth: CGFloat, visibleHeight: CGFloat
) -> (width: Int, height: Int) {
    let width = max(100, Int((visibleWidth * CGFloat(widthRatio)).rounded(.down)))
    let height: Int
    if let aspectRatio {
        height = max(100, Int((CGFloat(width) / CGFloat(aspectRatio)).rounded(.down)))
    } else {
        height = max(100, Int((visibleHeight * CGFloat(heightRatio)).rounded(.down)))
    }
    return fittedSize(
        requestedWidth: width, requestedHeight: height,
        maxWidth: Int(visibleWidth), maxHeight: Int(visibleHeight))
}

public func windowSize(for preset: WindowSizePreset, on screen: NSScreen?) -> (
    width: Int, height: Int
) {
    windowSize(
        widthRatio: preset.widthRatio,
        heightRatio: preset.heightRatio,
        aspectRatio: preset.aspectRatio,
        on: screen)
}

public func windowSize(for recommendation: InitialWindowSizeRecommendation, on screen: NSScreen?)
    -> (width: Int, height: Int)
{
    windowSize(
        widthRatio: recommendation.widthRatio,
        heightRatio: recommendation.heightRatio,
        aspectRatio: recommendation.aspectRatio,
        on: screen)
}

public func windowSize(
    for preset: WindowSizePreset, referenceScreen: NSScreen?, fittingScreen: NSScreen
) -> (width: Int, height: Int) {
    let requestedSize = windowSize(for: preset, on: referenceScreen)
    return fittedWindowSize(
        width: requestedSize.width,
        height: requestedSize.height,
        on: fittingScreen)
}

public func windowSize(for preset: WindowSizePreset, appliedTo site: Site, on screen: NSScreen) -> (
    width: Int, height: Int
) {
    let referenceScreen = hasExplicitDisplaySelection(site) ? screen : builtInScreen ?? screen
    return windowSize(for: preset, referenceScreen: referenceScreen, fittingScreen: screen)
}

public func effectiveWindowSize(for override: DisplaySizeOverride, on screen: NSScreen) -> (
    width: Int, height: Int
) {
    if let preset = WindowSizePresets.preset(withID: override.windowSizePreset) {
        return windowSize(for: preset, referenceScreen: screen, fittingScreen: screen)
    }
    return fittedWindowSize(width: override.width, height: override.height, on: screen)
}

public func effectiveWindowSize(for site: Site, on screen: NSScreen) -> (width: Int, height: Int) {
    if let override = displaySizeOverride(for: site, on: screen) {
        return effectiveWindowSize(for: override, on: screen)
    }
    if let preset = WindowSizePresets.preset(withID: site.windowSizePreset) {
        return windowSize(for: preset, appliedTo: site, on: screen)
    }
    return fittedWindowSize(width: site.width, height: site.height, on: screen)
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
    let fittedSize = effectiveWindowSize(for: site, on: screen)
    return centeredBounds(
        fittedWidth: fittedSize.width, fittedHeight: fittedSize.height,
        visibleFrame: screen.visibleFrame, primaryHeight: primaryH)
}

/// 이미 맞춰진 크기(fittedWidth×fittedHeight)를 가시영역 중앙에 배치하는 좌상단 원점
/// bounds를 계산하는 순수 코어. primaryHeight는 주 화면(글로벌 원점) 높이.
public func centeredBounds(
    fittedWidth bw: Int, fittedHeight bh: Int, visibleFrame: CGRect, primaryHeight: CGFloat
) -> (left: Int, top: Int, right: Int, bottom: Int) {
    let bx = Int(visibleFrame.minX + (visibleFrame.width - CGFloat(bw)) / 2)
    let by = Int(primaryHeight - visibleFrame.maxY + (visibleFrame.height - CGFloat(bh)) / 2)
    return (bx, by, bx + bw, by + bh)
}
