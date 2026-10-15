import AppKit
import SwiftUI

/// 노치 상단 띠의 Quick Note 아이콘이 여는 메모 창. 열 때마다 노치 바로 아래에 붙어서 뜨고,
/// 그다음엔 자유롭게 옮길 수 있다. 크기는 기억한다. 노치를 닫아도 다른 창 위에 떠 있다.
/// 창이 열려 있는 동안 아이콘은 이 창을 앞으로 가져온다 (편집기는 언제나 하나다).
enum QuickNoteWindow {
    private static var window: NSWindow?
    private static var closeObserver: NSObjectProtocol?
    private static var escapeMonitor: Any?

    static let defaultSize = NSSize(width: 420, height: 320)
    static let minimumSize = NSSize(width: 280, height: 180)
    private static let autosaveName = "ChapQuickNoteWindow"

    static var isOpen: Bool { window?.isVisible ?? false }

    static func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(
            rootView: QuickNoteWindowContent(onClose: { Self.window?.close() })
        )
        // 창 크기는 사용자가 정한다. SwiftUI 내용이 창을 되돌려 키우지 않게 한다.
        hosting.sizingOptions = []
        let window = QuickNoteNSWindow(contentViewController: hosting)
        window.title = "Quick Note"
        // 겉은 Chap이 전부 그린다. AppKit은 리사이즈·키 포커스·프레임 저장만 맡는다.
        window.styleMask = [.borderless, .resizable]
        window.isMovableByWindowBackground = false
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentMinSize = minimumSize
        window.setContentSize(defaultSize)
        // 지난번 크기만 되살리고, 자리는 늘 노치 아래에서 시작한다. autosave 이름을 먼저 달아야
        // 이름을 다는 순간 저장된 프레임이 다시 적용돼 자리가 덮이는 일이 없다.
        window.setFrameAutosaveName(autosaveName)
        window.setFrameUsingName(autosaveName)
        placeUnderNotch(window)

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            // 창을 닫기 직전 남은 입력을 저장하고, 다음에 열 때 최신 내용을 다시 읽도록 버린다.
            NotificationCenter.default.post(name: NotchQuickNoteView.flushRequest, object: nil)
            if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
            closeObserver = nil
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
            escapeMonitor = nil
            Self.window = nil
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event)
        }
        Self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Esc로 창을 닫는다. 메모 상자에서 타이핑 중이어도(TextEditor가 Esc를 먹기 전에) 받는다.
    /// 닫힘 경로가 하나라 `willClose`의 flush가 마지막 입력을 그대로 저장한다.
    /// - Returns: 삼켰으면 nil, 아니면 그대로 흘려보낼 이벤트.
    static func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.keyCode == 53, let open = window, event.window === open else { return event }
        open.close()
        return nil
    }

    /// 창 윗변을 노치 아랫변에 붙이고 노치 가운데에 맞춘다. 노치 화면이 없으면 커서 화면 가운데.
    private static func placeUnderNotch(_ window: NSWindow) {
        guard let screen = NotchLauncherController.notchScreen() else {
            centerOnCursorScreen(window)
            return
        }
        window.setFrameOrigin(
            QuickNotePlacement.origin(
                windowSize: window.frame.size,
                notchRect: NotchLauncherController.notchRect(on: screen),
                visibleFrame: screen.visibleFrame))
    }

    private static func centerOnCursorScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
                ?? NSScreen.main
        else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(
            NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }
}

/// Quick Note의 불투명 custom card. AppKit titlebar 대신 Chap 헤더·닫기·드래그 영역을 쓴다.
struct QuickNoteWindowContent: View {
    static let chromeHeight: CGFloat = 36

    private static let palette = NotchWidgetPalette(
        primary: .primary, secondary: .secondary, accent: DS.accent, heading: .secondary,
        textShadowOpacity: 0, hoverBackground: Color.primary.opacity(0.08),
        subtleSurface: Color.primary.opacity(0.12))

    /// 오프스크린 렌더만 실제 메모를 읽지 않도록 넣는 고정 문구.
    var previewText: String? = nil
    /// 실제 창의 × 버튼. nil이면 렌더 프리뷰라 닫기 버튼은 눌리지 않는다.
    var onClose: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            NotchQuickNoteView(
                palette: Self.palette,
                bodyHeight: max(geo.size.height - Self.chromeHeight - 15, 80),
                focusesOnAppear: true,
                toolbarHeight: Self.chromeHeight,
                showsToolbarDivider: true,
                previewText: previewText,
                onClose: onClose
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Glass가 아닌 불투명 card surface라 Light/Dark에서 메모와 헤더 대비가 흔들리지 않는다.
        .background(DS.cardBg)
        .frame(
            minWidth: QuickNoteWindow.minimumSize.width,
            minHeight: QuickNoteWindow.minimumSize.height)
    }
}

/// Quick Note 창. 표시 프로토콜로 메모 뷰가 이 창이 key를 잃는 순간을 알아본다.
final class QuickNoteNSWindow: NSWindow, QuickNoteWindowPanelMarker {}

/// borderless Quick Note의 빈 헤더를 AppKit 창 드래그 영역으로 만든다.
/// SwiftUI 버튼 위가 아니라 background에만 놓여 Copy·Backups·× 입력은 그대로 버튼이 받는다.
struct QuickNoteHeaderDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> HeaderDragView { HeaderDragView() }
    func updateNSView(_ nsView: HeaderDragView, context: Context) {}

    final class HeaderDragView: NSView {
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let initialMouseLocation = NSEvent.mouseLocation
            let initialOrigin = window.frame.origin
            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
                guard next.type != .leftMouseUp else { break }
                let location = NSEvent.mouseLocation
                window.setFrameOrigin(
                    NSPoint(
                        x: initialOrigin.x + location.x - initialMouseLocation.x,
                        y: initialOrigin.y + location.y - initialMouseLocation.y))
            }
        }
    }
}
