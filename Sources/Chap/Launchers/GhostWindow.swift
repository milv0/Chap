import Cocoa

enum GhostWindow {
    private static var window: NSWindow?

    static func show(bounds: (left: Int, top: Int, right: Int, bottom: Int)) {
        DispatchQueue.main.async {
            let width = CGFloat(bounds.right - bounds.left)
            let height = CGFloat(bounds.bottom - bounds.top)
            let primaryH = NSScreen.screens.first?.frame.height ?? 900
            let frame = NSRect(
                x: CGFloat(bounds.left),
                y: primaryH - CGFloat(bounds.top) - height,
                width: width,
                height: height
            )

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
    }

    static func dismiss() {
        DispatchQueue.main.async {
            guard let w = window else { return }
            NSAnimationContext.runAnimationGroup(
                { ctx in
                    ctx.duration = 0.2
                    w.animator().alphaValue = 0
                },
                completionHandler: {
                    w.orderOut(nil)
                    window = nil
                })
        }
    }
}
