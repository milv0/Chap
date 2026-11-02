import AppKit

/// 노치 옆 Drop·Timer 배지가 공유하는 투명 보조 창 shell.
/// 콘텐츠와 앞뒤 순서는 각 배지 호출자가 정하고, 창 속성만 여기서 한 번에 맞춘다.
enum NotchAuxiliaryWindow {
    static func make(frame: NSRect, level: NSWindow.Level) -> NSWindow {
        let window = NSWindow(
            contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = level
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        return window
    }
}
