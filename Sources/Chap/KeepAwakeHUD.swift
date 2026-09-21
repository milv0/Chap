import Cocoa

/// Keep Awake 상태 변화를 화면 중앙에 잠깐 보여주는 HUD 오버레이.
///
/// GuideWindow와 같은 토큰 방식으로 빠른 연속 토글 시 유령 창을 막는다.
/// 표시 후 잠시 뒤 스스로 페이드아웃하며, 마우스 이벤트를 가로채지 않는다.
/// 모든 호출은 내부에서 메인 큐로 직렬화된다.
enum KeepAwakeHUD {
    private static var window: NSWindow?
    private static var lastToken = 0

    private static let hudSize = NSSize(width: 230, height: 150)
    private static let visibleDuration: TimeInterval = 2.2
    /// 앱 테마 색 (DS.accent와 동일). GuideWindow와 같은 컬러감을 위해 사용한다.
    private static let accent = NSColor(
        red: 54 / 255, green: 100 / 255, blue: 255 / 255, alpha: 1)

    /// 심볼과 문구로 HUD를 띄운다. 이전 HUD가 떠 있으면 즉시 교체한다.
    static func show(message: String, symbolName: String) {
        DispatchQueue.main.async {
            lastToken += 1
            let token = lastToken

            if let old = window {
                old.orderOut(nil)
                window = nil
            }
            guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.midX - hudSize.width / 2,
                y: visible.midY - hudSize.height / 2)
            let hud = NSWindow(
                contentRect: NSRect(origin: origin, size: hudSize),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            hud.level = .statusBar
            hud.isOpaque = false
            hud.backgroundColor = .clear
            hud.hasShadow = false
            hud.ignoresMouseEvents = true
            hud.collectionBehavior = [.canJoinAllSpaces, .transient]
            hud.contentView = makeContentView(message: message, symbolName: symbolName)

            hud.alphaValue = 0
            hud.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                hud.animator().alphaValue = 1
            }
            window = hud

            DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) {
                dismiss(token)
            }
        }
    }

    private static func dismiss(_ token: Int) {
        guard token == lastToken, let hud = window else { return }
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.3
                hud.animator().alphaValue = 0
            },
            completionHandler: {
                hud.orderOut(nil)
                if lastToken == token {
                    window = nil
                }
            })
    }

    private static func makeContentView(message: String, symbolName: String) -> NSView {
        // GuideWindow와 같은 컬러감: 밝은 반투명 바탕 + 테마색 틴트/테두리.
        let container = NSVisualEffectView(
            frame: NSRect(origin: .zero, size: hudSize))
        container.material = .popover
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 2
        container.layer?.borderColor = accent.withAlphaComponent(0.6).cgColor

        let tint = NSView(frame: NSRect(origin: .zero, size: hudSize))
        tint.wantsLayer = true
        tint.layer?.backgroundColor = accent.withAlphaComponent(0.1).cgColor
        tint.autoresizingMask = [.width, .height]

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 44, weight: .medium)
        let imageView = NSImageView(
            frame: NSRect(x: 0, y: 52, width: hudSize.width, height: 66))
        imageView.image = NSImage(
            systemSymbolName: symbolName, accessibilityDescription: message)?
            .withSymbolConfiguration(symbolConfig)
        imageView.contentTintColor = accent
        imageView.imageAlignment = .alignCenter

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = accent
        label.alignment = .center
        label.frame = NSRect(x: 8, y: 22, width: hudSize.width - 16, height: 20)

        container.addSubview(tint)
        container.addSubview(imageView)
        container.addSubview(label)
        return container
    }
}
