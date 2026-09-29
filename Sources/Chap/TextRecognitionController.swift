import AppKit
import ScreenCaptureKit
import Vision
import os

/// 화면 영역 텍스트 인식: 영역을 드래그하면 그 안의 글자를 읽어 클립보드에 복사한다.
///
/// 흐름: 화면 기록 권한 확인 → 모든 화면에 어두운 선택 오버레이 → 드래그 → 오버레이 닫기
/// → ScreenCaptureKit으로 그 영역만 메모리에 캡처(Chap 창 제외) → Vision 인식(한국어·영어)
/// → 클립보드 복사 → 노치 아래 알림. 캡처 이미지는 파일로 저장하지 않는다.
/// 창·커서·클립보드는 메인 스레드에서만 다루고, 캡처·인식만 비동기로 돈다.
final class TextRecognitionController {
    /// 노치 띠 아이콘 등 UI가 인식을 시작해 달라고 요청한다.
    static let requestNotification = Notification.Name("ChapRecognizeTextRequest")

    private var overlays: [TextSelectionWindow] = []
    private var isBusy = false

    func start() {
        precondition(Thread.isMainThread)
        guard !isBusy else { return }
        guard CGPreflightScreenCaptureAccess() else {
            requestPermission()
            return
        }
        isBusy = true
        showOverlays()
    }

    // MARK: - Permission

    private func requestPermission() {
        // 첫 요청이면 macOS 권한 창이 뜬다. 이미 거부했다면 창 없이 false가 돌아온다.
        _ = CGRequestScreenCaptureAccess()
        let alert = NSAlert()
        alert.messageText = "Allow Chap to read text on screen"
        alert.informativeText =
            "Turn on Chap in System Settings → Privacy & Security → Screen & System Audio "
            + "Recording, then reopen Chap. Chap captures only the area you select, keeps it in "
            + "memory, and never saves or sends it."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Selection overlay

    private func showOverlays() {
        NSApp.activate(ignoringOtherApps: true)
        overlays = NSScreen.screens.map { screen in
            let window = TextSelectionWindow(screen: screen)
            window.onFinish = { [weak self] rect in self?.finishSelection(rect, on: screen) }
            window.orderFrontRegardless()
            return window
        }
        // 커서가 있는 화면의 오버레이가 Esc를 받는다.
        let mouse = NSEvent.mouseLocation
        (overlays.first { $0.frame.contains(mouse) } ?? overlays.first)?.makeKey()
        NSCursor.crosshair.push()
    }

    private func closeOverlays() {
        NSCursor.pop()
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
    }

    private func finishSelection(_ rect: CGRect?, on screen: NSScreen) {
        closeOverlays()
        guard let rect else {
            isBusy = false
            return
        }
        Task {
            let outcome = await Self.recognize(globalRect: rect, on: screen)
            await MainActor.run {
                self.present(outcome, on: screen)
                self.isBusy = false
            }
        }
    }

    // MARK: - Capture + recognize

    private enum Outcome {
        case text(String)
        case failed
    }

    private static func recognize(globalRect: CGRect, on screen: NSScreen) async -> Outcome {
        do {
            let image = try await capture(globalRect: globalRect, on: screen)
            return .text(try await recognizeText(in: image))
        } catch {
            Log.app.error(
                "Text recognition failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    @MainActor
    private func present(_ outcome: Outcome, on screen: NSScreen) {
        switch outcome {
        case .text(let text):
            if let message = TextRecognitionPolicy.copiedMessage(for: text) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                NotchToast.show(message: message, symbolName: "text.viewfinder", on: screen)
            } else {
                NotchToast.show(
                    message: TextRecognitionPolicy.noTextMessage,
                    symbolName: "text.magnifyingglass", on: screen)
            }
        case .failed:
            NotchToast.show(
                message: "Couldn't read that area", symbolName: "exclamationmark.triangle",
                on: screen)
        }
    }

    private static func capture(globalRect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        let displayID =
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value
        guard let display = content.displays.first(where: { $0.displayID == displayID })
        else { throw RecognitionError.displayUnavailable }
        // Chap 자신의 창(노치, 알림)은 캡처에서 뺀다.
        let ownApps = content.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let filter = SCContentFilter(
            display: display, excludingApplications: ownApps, exceptingWindows: [])
        let sourceRect = TextRecognitionPolicy.captureRect(
            forGlobalRect: globalRect, screenFrame: screen.frame)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        // 레티나 해상도 그대로 캡처해야 작은 글자도 읽힌다.
        let scale = screen.backingScaleFactor
        configuration.width = max(Int(sourceRect.width * scale), 1)
        configuration.height = max(Int(sourceRect.height * scale), 1)
        configuration.showsCursor = false
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: configuration)
    }

    private static func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = TextRecognitionPolicy.recognitionLanguages
                request.usesLanguageCorrection = true
                do {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                    let lines = (request.results ?? []).compactMap {
                        observation -> TextRecognitionPolicy.Line? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return TextRecognitionPolicy.Line(
                            text: candidate.string, box: observation.boundingBox)
                    }
                    continuation.resume(returning: TextRecognitionPolicy.joinedText(lines))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private enum RecognitionError: LocalizedError {
        case displayUnavailable
        var errorDescription: String? { "The selected display is not available for capture." }
    }
}

// MARK: - Selection window

/// 화면 하나를 덮는 어두운 선택 창. 드래그한 영역만 밝게 뚫어 보여주고,
/// 놓으면 전역 좌표 사각형을, Esc·너무 작은 드래그면 nil을 돌려준다.
final class TextSelectionWindow: NSPanel {
    var onFinish: ((CGRect?) -> Void)?
    private var didFinish = false

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setFrame(screen.frame, display: false)
        let view = TextSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.onFinish = { [weak self] localRect in
            guard let self else { return }
            self.finish(localRect.map { self.convertToScreen($0) })
        }
        view.onCancel = { [weak self] in self?.finish(nil) }
        contentView = view
        initialFirstResponder = view
    }

    override var canBecomeKey: Bool { true }

    private func finish(_ rect: CGRect?) {
        guard !didFinish else { return }
        didFinish = true
        onFinish?(rect)
    }
}

private final class TextSelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    var onCancel: (() -> Void)?
    private var start: CGPoint?
    private var current: CGPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let end = convert(event.locationInWindow, from: nil)
        guard let start else {
            onCancel?()
            return
        }
        onFinish?(TextRecognitionPolicy.selectionRect(from: start, to: end))
    }

    override func rightMouseDown(with event: NSEvent) { onCancel?() }

    private var selection: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        if let selection {
            dim.append(NSBezierPath(rect: selection))
            dim.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.28).setFill()
        dim.fill()
        guard let selection else { return }
        let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        NSColor(red: 54 / 255, green: 100 / 255, blue: 1, alpha: 1).setStroke()
        border.stroke()
    }
}

// MARK: - Toast

/// 노치(또는 메뉴 막대) 바로 아래에 잠깐 뜨는 작은 알림. 마우스 이벤트를 가로채지 않는다.
enum NotchToast {
    private static var window: NSWindow?
    private static var token = 0
    private static let visibleDuration: TimeInterval = 2.2

    @MainActor
    static func show(message: String, symbolName: String, on screen: NSScreen) {
        token += 1
        let current = token
        window?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        let icon = NSImageView(
            image: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage()
        )
        icon.contentTintColor = .white
        let stack = NSStackView(views: [icon, label])
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 16)

        let width = min(max(stack.fittingSize.width, 160), 420)
        let height: CGFloat = 34
        let topInset = screen.safeAreaInsets.top
        let top = topInset > 0 ? screen.frame.maxY - topInset : screen.visibleFrame.maxY
        let frame = CGRect(
            x: screen.frame.midX - width / 2, y: top - 10 - height, width: width, height: height)

        let toast = NSWindow(
            contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        toast.level = .statusBar
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.ignoresMouseEvents = true
        toast.collectionBehavior = [.canJoinAllSpaces, .transient]
        let background = NSView(frame: CGRect(origin: .zero, size: frame.size))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.92).cgColor
        background.layer?.cornerRadius = height / 2
        stack.frame = background.bounds
        stack.autoresizingMask = [.width, .height]
        background.addSubview(stack)
        toast.contentView = background
        toast.setAccessibilityLabel(message)
        NSAccessibility.post(
            element: toast, notification: .announcementRequested,
            userInfo: [
                .announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])

        toast.alphaValue = 0
        toast.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.15
            toast.animator().alphaValue = 1
        }
        window = toast
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) {
            guard current == token, let toast = window else { return }
            NSAnimationContext.runAnimationGroup(
                {
                    $0.duration = 0.3
                    toast.animator().alphaValue = 0
                },
                completionHandler: {
                    toast.orderOut(nil)
                    if current == token { window = nil }
                })
        }
    }
}
