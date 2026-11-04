import SwiftUI

/// accessory 앱의 Settings가 비활성일 때도 첫 클릭을 실제 SwiftUI Button에 전달한다.
private final class SettingsFirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Settings 전용 hosting controller. 기본 NSHostingController 대신 first-mouse view를 쓴다.
final class SettingsHostingController<Content: View>: NSViewController {
    init(rootView: Content) {
        super.init(nibName: nil, bundle: nil)
        let hosting = SettingsFirstMouseHostingView(rootView: rootView)
        // AppKit owns the user's window size. SwiftUI should fill it, not publish a fitting size
        // that snaps the resizable Settings window back to its content height.
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: SettingsView.initialSize)
        hosting.autoresizingMask = [.width, .height]
        view = hosting
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
