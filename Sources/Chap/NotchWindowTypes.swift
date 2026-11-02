import AppKit

/// mouseEntered 콜백과 파일 드래그 진입 콜백을 제공하는 추적 뷰.
/// 파일을 끌고 있는 동안에는 tracking area가 발화하지 않으므로 드래그 진입도 패널 열기 신호로 받는다.
final class NotchHoverView: NSView {
    var onEntered: () -> Void = {}
    var onDragEntered: () -> Void = {}
    var onDragExited: () -> Void = {}
    /// 설정 시 이 뷰 자체가 드롭 타깃이 된다. 도커가 뜨기 전 배지·노치에 바로 놓아도 성사된다.
    var onFilesDropped: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onEntered() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered()
        return onFilesDropped != nil ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let onFilesDropped else { return false }
        let urls =
            sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onFilesDropped(urls)
        return true
    }
}

/// 메인 도커 패널. 빠른 메모 입력을 위해 borderless nonactivating panel도 key가 될 수 있다.
final class NotchKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
