import AppKit
import SwiftUI

/// 노치에서 분리한 Quick Note 창. 노치를 닫아도 다른 창 위에 떠 있고, 크기·위치를 기억한다.
/// 노치 메모와 같은 파일(`QuickNoteStore`)을 쓰며, 창이 열려 있는 동안 노치의 메모 아이콘은
/// 이 창을 앞으로 가져온다 (두 편집기가 동시에 같은 파일을 고치지 않게 한다).
enum QuickNoteWindow {
    private static var window: NSWindow?
    private static var closeObserver: NSObjectProtocol?

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
        let hosting = NSHostingController(rootView: QuickNoteWindowContent())
        // 창 크기는 사용자가 정한다. SwiftUI 내용이 창을 되돌려 키우지 않게 한다.
        hosting.sizingOptions = []
        let window = QuickNoteNSWindow(contentViewController: hosting)
        window.title = "Quick Note"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentMinSize = minimumSize
        window.setContentSize(defaultSize)
        if !window.setFrameUsingName(autosaveName) {
            centerOnCursorScreen(window)
        }
        window.setFrameAutosaveName(autosaveName)

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            // 창을 닫기 직전 남은 입력을 저장하고, 다음에 열 때 최신 내용을 다시 읽도록 버린다.
            NotificationCenter.default.post(name: NotchQuickNoteView.flushRequest, object: nil)
            if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
            closeObserver = nil
            Self.window = nil
        }
        Self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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

/// 분리 창의 내용: 시스템 색으로 그린 넓은 메모 편집기와 복사 버튼.
private struct QuickNoteWindowContent: View {
    private static let palette = NotchWidgetPalette(
        primary: .primary, secondary: .secondary, accent: DS.accent, heading: .secondary,
        textShadowOpacity: 0, hoverBackground: Color.primary.opacity(0.08),
        subtleSurface: Color.primary.opacity(0.12))

    var body: some View {
        GeometryReader { geo in
            NotchQuickNoteView(
                palette: Self.palette, showsHeader: false,
                bodyHeight: max(geo.size.height - DS.notchHeaderHeight - 7, 80),
                focusesOnAppear: true,
                toolbar: NotchQuickNoteToolbar(onDetach: nil, onClose: nil))
        }
        .padding(12)
        .frame(
            minWidth: QuickNoteWindow.minimumSize.width,
            minHeight: QuickNoteWindow.minimumSize.height)
    }
}

/// 분리된 Quick Note 창. 표시 프로토콜로 메모 뷰가 이 창이 key를 잃는 순간을 알아본다.
final class QuickNoteNSWindow: NSWindow, QuickNoteWindowPanelMarker {}
