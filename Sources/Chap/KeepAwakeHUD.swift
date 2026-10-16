import Cocoa

/// Keep Awake 상태 변화를 화면 중앙에 잠깐 보여주는 HUD 오버레이.
///
/// GuideWindow와 같은 토큰 방식으로 빠른 연속 토글 시 유령 창을 막는다.
/// 그림은 앱 아이콘·노치와 같은 픽셀 물범이다: 켜면 꼬리를 든 깨어 있는 Chap, 끄면 눈 감고 z를 띄운 Chap.
/// 물범은 두 모습에서 같은 자리에 있고, z는 머리 위 여백만 채운다.
/// 노치가 있는 내장 화면에만 띄운다. 노치가 없는 Mac에서는 사운드와 상태바 아이콘 색이 알림 역할을 한다.
/// 표시 후 잠시 뒤 스스로 페이드아웃하며, 마우스 이벤트를 가로채지 않는다.
/// 모든 호출은 내부에서 메인 큐로 직렬화된다.
enum KeepAwakeHUD {
    private static var window: NSWindow?
    private static var lastToken = 0

    private static let hudSize = NSSize(width: 230, height: 150)
    private static let visibleDuration: TimeInterval = 2.2
    /// 앱 테마 색 (DS.accent와 동일). GuideWindow와 같은 컬러감을 위해 사용한다.
    private static let accent = DS.accentNSColor

    /// 문구와 Focus 상태로 HUD를 띄운다. 이전 HUD가 떠 있으면 즉시 교체한다.
    /// - Parameter focusOn: 켜는 중이면 깨어 있는 물범, 끄는 중이면 잠든 물범을 그린다.
    /// - Parameter anyScreen: 노치 화면이 없어도 커서가 있는 화면에 띄운다(타이머 끝 알림처럼 놓치면 안 될 때).
    static func show(message: String, focusOn: Bool, anyScreen: Bool = false) {
        DispatchQueue.main.async {
            lastToken += 1
            let token = lastToken

            if let old = window {
                old.orderOut(nil)
                window = nil
            }
            // Chap(물범)은 노치의 친구다. HUD도 노치가 있는 내장 화면 가운데에만 띄운다.
            guard
                let screen = NotchLauncherController.notchScreen()
                    ?? (anyScreen ? cursorScreen : nil)
            else { return }

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
            hud.contentView = makeContentView(message: message, focusOn: focusOn)

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

    /// (개발용) 렌더 도구가 HUD 모습을 PNG로 뽑을 때도 쓴다.
    static func makeContentView(message: String, focusOn: Bool) -> NSView {
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

        // 파란 타일 없이 HUD 바탕에 바로 올린다. 바탕(옅은 popover + 테마색 틴트)이 이미 한 겹이라
        // 타일까지 두면 상자 안의 상자가 된다. 흰 몸통은 픽셀 물범의 어두운 테두리가 모양을 잡아 준다.
        // 켜짐: 깨어 꼬리를 든 Chap. 꺼짐: 눈 감고 z를 띄운 Chap.
        let seal = ChapMascotImage.image(
            pixelSize: 4, eyes: focusOn ? .open : .closed, pose: focusOn ? .tailUp : .rest,
            showsSleepZ: !focusOn)
        let imageView = NSImageView(
            frame: NSRect(x: (hudSize.width - 132) / 2, y: 54, width: 132, height: 72))
        imageView.image = seal
        imageView.imageScaling = .scaleNone
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
