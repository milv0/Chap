import Cocoa

/// 리사이즈 위치를 미리 보여주는 가이드 오버레이 윈도우.
///
/// 단일 공유 윈도우를 쓰되, 빠른 연속 실행에서 유령 창이 남지 않도록 토큰으로
/// 소유권을 구분한다. `show`가 반환한 토큰을 `dismiss(_:)`에 넘기면, 그 사이 다른
/// 실행이 새 가이드를 띄운 경우(토큰 불일치) 남의 창을 건드리지 않는다.
///
/// 모든 show/dismiss 호출은 메인 스레드(launchSite)에서 시작되고 내부 작업도
/// 메인 큐에서 실행되므로 상태 접근은 직렬화되어 있다.
enum GuideWindow {
    private static var window: NSWindow?
    /// 현재 화면에 떠 있어야 하는 가이드의 토큰.
    private static var currentToken: Int = 0
    /// show가 발급한 마지막 토큰(단조 증가).
    private static var lastToken: Int = 0

    /// 가이드 윈도우를 띄우고, 이 호출을 식별하는 토큰을 반환한다.
    @discardableResult
    static func show(bounds: (left: Int, top: Int, right: Int, bottom: Int)) -> Int {
        lastToken += 1
        let token = lastToken
        DispatchQueue.main.async {
            currentToken = token
            // 이전 가이드 윈도우가 남아 있으면 먼저 정리 (연속 실행 시 유령 윈도우 방지)
            if let old = window {
                old.orderOut(nil)
                window = nil
            }
            let frame = appKitFrame(fromTopLeft: bounds)

            let w = NSWindow(
                contentRect: frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = true

            let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
            view.wantsLayer = true
            view.layer?.cornerRadius = 10
            view.layer?.borderWidth = 2
            view.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
            view.layer?.backgroundColor =
                NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
            w.contentView = view

            w.alphaValue = 0
            w.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                w.animator().alphaValue = 1
            }

            window = w
        }
        return token
    }

    /// `show`가 반환한 토큰의 가이드를 닫는다. 그 사이 새 가이드가 떴다면 무시한다.
    static func dismiss(_ token: Int) {
        DispatchQueue.main.async {
            // 이미 다른 실행이 새 가이드를 띄웠다면 내 창은 그 show가 정리했으므로 건드리지 않음.
            guard token == currentToken, let w = window else { return }
            NSAnimationContext.runAnimationGroup(
                { ctx in
                    ctx.duration = 0.2
                    w.animator().alphaValue = 0
                },
                completionHandler: {
                    w.orderOut(nil)
                    // 페이드 도중 새 가이드가 떴다면(토큰이 바뀌었다면) 공유 상태는 건드리지 않는다.
                    if currentToken == token {
                        window = nil
                    }
                })
        }
    }
}
