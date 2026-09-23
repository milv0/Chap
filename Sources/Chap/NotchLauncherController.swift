import Cocoa
import SwiftUI

/// 노치 아래에 런처 목록 패널을 띄우는 컨트롤러.
///
/// 상태바 NSMenu를 대체하지 않는 추가 표면이다. 노치 위 투명 핫존에 마우스가
/// 올라오면 패널을 펼치고, 마우스가 노치·패널 영역 밖에 머물면 닫는다.
/// `.nonactivatingPanel`이라 전면 앱 포커스를 빼앗지 않는다.
///
/// 표시 중 판단은 tracking area가 아니라 마우스 위치 폴링 하나로만 한다.
/// 겹친 두 창의 entered/exited 경합(패널 등장 → 핫존 exited → 숨김 →
/// 핫존 entered → 재등장)이 플리커를 만들기 때문이다.
/// 모든 호출은 메인 스레드 전제(AppKit 윈도우 소유).
final class NotchLauncherController {
    private var hotzoneWindow: NSWindow?
    private var panel: NSPanel?
    private var visibilityTimer: Timer?
    private var lastInsideDate = Date()

    /// 패널에 표시할 섹션 공급자. 항상 최신 config 기준으로 재계산된다.
    var sectionsProvider: () -> [LauncherListSection] = { [] }
    /// 패널 시각 스타일 공급자.
    var styleProvider: () -> NotchPanelStyle = { .black }
    /// 항목 실행 콜백. `config.sites` 원본 인덱스를 넘긴다.
    var onLaunch: (Int) -> Void = { _ in }

    private static let panelMinWidth: CGFloat = 300
    /// 노치·패널 밖에서 이 시간 이상 머물면 닫는다.
    private static let hideDelay: TimeInterval = 0.4
    private static let pollInterval: TimeInterval = 0.08
    /// 경계에서의 미세한 좌표 흔들림으로 닫히지 않도록 주는 여유.
    private static let dwellMargin: CGFloat = 6

    /// 토글/노치 유무에 따라 핫존을 켜거나 끈다. 조건이 안 되면 전부 내린다.
    func update(enabled: Bool) {
        guard let screen = Self.notchScreen(),
            NotchLauncherPolicy.shouldPresent(
                enabled: enabled, topSafeAreaInset: screen.safeAreaInsets.top)
        else {
            tearDown()
            return
        }
        installHotzone(on: screen)
    }

    func tearDown() {
        stopVisibilityMonitor()
        panel?.orderOut(nil)
        panel = nil
        hotzoneWindow?.orderOut(nil)
        hotzoneWindow = nil
    }

    // MARK: - Hotzone

    private func installHotzone(on screen: NSScreen) {
        hotzoneWindow?.orderOut(nil)

        let frame = Self.notchRect(on: screen)
        let window = NSWindow(
            contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false

        let tracker = HoverView(frame: NSRect(origin: .zero, size: frame.size))
        // 열기만 tracking area가 담당하고, 닫기는 전부 폴링이 담당한다.
        tracker.onEntered = { [weak self] in self?.showPanel() }
        window.contentView = tracker
        window.orderFrontRegardless()
        hotzoneWindow = window
    }

    /// 노치 rect. 노치 좌우의 auxiliary area 사이 간격이 노치 폭이다.
    /// auxiliary API가 값을 주지 않으면 중앙 200pt로 폴백한다.
    private static func notchRect(on screen: NSScreen) -> NSRect {
        let inset = screen.safeAreaInsets.top
        let top = screen.frame.maxY - inset
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NSRect(
                x: left.maxX, y: top, width: right.minX - left.maxX, height: inset)
        }
        return NSRect(x: screen.frame.midX - 100, y: top, width: 200, height: inset)
    }

    private static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }

    // MARK: - Panel

    private func showPanel() {
        guard panel == nil, let screen = Self.notchScreen() else { return }

        let sections = sectionsProvider()
        guard !sections.isEmpty else { return }

        // 노치보다 넓게 잡아야 "노치가 자라난" 실루엣이 된다.
        // 최종 폭은 가로로 배치된 섹션 수에 따라 자연 크기로 커진다.
        let inset = screen.safeAreaInsets.top
        let notchWidth = Self.notchRect(on: screen).width
        let minWidth = max(notchWidth + 80, Self.panelMinWidth)

        let content = NotchLauncherPanelView(
            minWidth: minWidth,
            topInset: inset,
            style: styleProvider(),
            sections: sections,
            onLaunch: { [weak self] siteIndex in
                self?.hidePanel()
                self?.onLaunch(siteIndex)
            })
        let hosting = NSHostingView(rootView: content)
        // 노치 구간 safe area가 콘텐츠를 아래로 밀지 않게 한다.
        hosting.safeAreaRegions = []
        // fittingSize에는 노치 감싸기용 top padding이 이미 포함되어 있으므로
        // 정책에는 콘텐츠 높이만 전달해 inset이 두 번 더해지지 않게 한다.
        // 소수점 크기는 올림해 상단이 서브픽셀로 내려앉는 틈을 막는다.
        let fitting = hosting.fittingSize
        let size = CGSize(width: ceil(fitting.width), height: ceil(fitting.height))
        var frame = NotchLauncherPolicy.panelFrame(
            screenFrame: screen.frame,
            topSafeAreaInset: inset,
            contentSize: CGSize(width: size.width, height: size.height - inset))
        // 픽셀 정렬 후에도 상단 변이 정확히 화면 최상단에 오도록 y를 재고정한다.
        frame = frame.integral
        frame.origin.y = screen.frame.maxY - frame.height

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // 그림자는 SwiftUI 쪽 확산 그림자가 담당한다. 시스템 그림자는 스케일
        // 등장 중 형태를 따라오지 못해 잔상을 만들므로 끈다.
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = hosting

        // 등장 애니메이션은 SwiftUI 콘텐츠가 노치 기준 확장으로 처리한다.
        panel.orderFrontRegardless()
        self.panel = panel
        startVisibilityMonitor()
    }

    /// 마우스가 노치·패널을 벗어난 채 `hideDelay`를 넘기면 닫는다.
    private func startVisibilityMonitor() {
        stopVisibilityMonitor()
        lastInsideDate = Date()
        visibilityTimer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval, repeats: true
        ) { [weak self] _ in
            self?.evaluateVisibility()
        }
    }

    private func stopVisibilityMonitor() {
        visibilityTimer?.invalidate()
        visibilityTimer = nil
    }

    private func evaluateVisibility() {
        guard let panel else {
            stopVisibilityMonitor()
            return
        }
        let location = NSEvent.mouseLocation
        let stayRegion = panel.frame
            .union(hotzoneWindow?.frame ?? panel.frame)
            .insetBy(dx: -Self.dwellMargin, dy: -Self.dwellMargin)
        if stayRegion.contains(location) {
            lastInsideDate = Date()
            return
        }
        if Date().timeIntervalSince(lastInsideDate) >= Self.hideDelay {
            hidePanel()
        }
    }

    private func hidePanel() {
        stopVisibilityMonitor()
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.15
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                panel.orderOut(nil)
            })
    }
}

/// mouseEntered 콜백만 제공하는 추적 뷰.
private final class HoverView: NSView {
    var onEntered: () -> Void = {}

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
}
