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
    private var badgeWindow: NSWindow?
    /// 현재 떠 있는 표면. 배지 z순서와 hover 전환 판단에 쓴다.
    private enum ActiveSurface { case mainPanel, dropDock }
    private var activeSurface: ActiveSurface?
    private var dropObserver: NSObjectProtocol?
    private var visibilityTimer: Timer?
    private var lastInsideDate = Date()
    /// 현재 패널의 펼침/불투명도 모델. 패널이 없으면 nil.
    private var revealModel: NotchRevealModel?
    /// 설정 슬라이더 프리뷰 중에는 자동 숨김을 멈추고 패널을 고정한다.
    private var isPreviewPinned = false

    /// 패널에 표시할 위젯 칸 공급자. 항상 최신 config 기준으로 재계산된다.
    var slotsProvider: () -> [NotchSlotContent] = { [] }
    /// 패널 시각 스타일 공급자.
    var styleProvider: () -> NotchPanelStyle = { .black }
    /// 패널 하단 불투명도 공급자.
    var opacityProvider: () -> Double = { Config.notchPanelOpacityDefault }
    /// 콘텐츠 박스 배경색 공급자 ("#RRGGBB").
    var colorProvider: () -> String = { Config.notchPanelColorHexDefault }
    /// 항목 실행 콜백. `config.sites` 원본 인덱스를 넘긴다.
    var onLaunch: (Int) -> Void = { _ in }

    private static let panelMinWidth: CGFloat = 300
    /// 노치·패널 밖에서 이 시간 이상 머물면 닫는다.
    private static let hideDelay: TimeInterval = 0.2
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
        installDropObserverIfNeeded()
        updateDropBadge()
    }

    func tearDown() {
        stopVisibilityMonitor()
        isPreviewPinned = false
        activeSurface = nil
        revealModel = nil
        panel?.orderOut(nil)
        panel = nil
        hotzoneWindow?.orderOut(nil)
        hotzoneWindow = nil
        badgeWindow?.orderOut(nil)
        badgeWindow = nil
        if let dropObserver {
            NotificationCenter.default.removeObserver(dropObserver)
            self.dropObserver = nil
        }
    }

    // MARK: - Drop badge

    private func installDropObserverIfNeeded() {
        guard dropObserver == nil else { return }
        dropObserver = NotificationCenter.default.addObserver(
            forName: ChapDrop.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateDropBadge()
        }
    }

    /// 보관함 파일 수에 따라 노치 왼쪽 Drop 배지 도커를 갱신한다.
    private func updateDropBadge() {
        let count = ChapDrop.fileCount()
        guard NotchLauncherPolicy.shouldShowDropBadge(fileCount: count),
            hotzoneWindow != nil, let screen = Self.notchScreen()
        else {
            badgeWindow?.orderOut(nil)
            badgeWindow = nil
            return
        }

        // 창은 인식 여유만큼 크게 잡고, 시각(배지 셰이프)은 원래 프레임에
        // 남도록 콘텐츠를 같은 값으로 인셋한다 (상단은 화면 끝이라 그대로).
        let margin = NotchGeometry.hoverMargin
        let visualFrame = NotchLauncherPolicy.dropBadgeFrame(
            notchRect: Self.notchRect(on: screen))
        let frame = NSRect(
            x: visualFrame.minX - margin, y: visualFrame.minY - margin,
            width: visualFrame.width + margin * 2, height: visualFrame.height + margin)
        let hosting = NSHostingView(
            rootView: NotchDropBadgeView(count: count)
                .padding(.horizontal, margin)
                .padding(.bottom, margin))
        // tracker가 항상 contentView여야 한다. 갱신 때 hosting만 넣으면
        // hover/드래그 콜백이 사라지는 회귀가 있었다 (첫 드롭 직후 재현).
        // hosting이 contentView여야 SwiftUI 좌표가 도커들과 동일하게 선다.
        // (tracker 안에 subview로 넣으면 셰이프가 상하 반전되어 렌더링됐다.)
        // tracker는 hosting 위의 투명 오버레이로 hover/드래그만 받는다.
        let tracker = HoverView(frame: NSRect(origin: .zero, size: frame.size))
        // 배지 hover는 Drop 파일 리스트 도커를, 파일 드래그는 드롭 존을 연다.
        tracker.onEntered = { [weak self] in
            guard let self else { return }
            // 메인 패널이 떠 있으면 즉시 내리고 Drop 파일 도커로 전환한다.
            if self.activeSurface == .mainPanel { self.dismissPanelImmediately() }
            self.showDropPanel()
        }
        tracker.onDragEntered = { [weak self] in self?.showDropZone() }
        // 드롭존 도커가 뜨기 전에 배지 위에 바로 놓아도 드롭이 성사된다.
        tracker.onFilesDropped = { [weak self] urls in
            ChapDrop.store(urls)
            self?.hidePanel()
        }
        tracker.autoresizingMask = [.width, .height]
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.addSubview(tracker)

        if let existing = badgeWindow {
            existing.setFrame(frame, display: true)
            existing.contentView = hosting
            // 배지는 어떤 도커 위에서도 앞에 남는다.
            if let panel {
                existing.order(.above, relativeTo: panel.windowNumber)
            } else {
                existing.orderFrontRegardless()
            }
            return
        }

        let window = NSWindow(
            contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.contentView = hosting
        if let panel {
            window.order(.above, relativeTo: panel.windowNumber)
        } else {
            window.orderFrontRegardless()
        }
        badgeWindow = window
    }

    // MARK: - Hotzone

    private func installHotzone(on screen: NSScreen) {
        hotzoneWindow?.orderOut(nil)

        // 인식 범위는 노치보다 hoverMargin만큼 넓다 (상단은 화면 끝이라 그대로).
        let notch = Self.notchRect(on: screen)
        let margin = NotchGeometry.hoverMargin
        let frame = NSRect(
            x: notch.minX - margin, y: notch.minY - margin,
            width: notch.width + margin * 2, height: notch.height + margin)
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
        // 마우스 hover는 전체 패널을, 파일 드래그는 컴팩트 드롭 존을 연다.
        tracker.onEntered = { [weak self] in
            guard let self else { return }
            // Drop 도커가 떠 있으면 즉시 내리고 메인 도커로 되돌아간다.
            if self.activeSurface == .dropDock { self.dismissPanelImmediately() }
            self.showPanel()
        }
        tracker.onDragEntered = { [weak self] in self?.showDropZone() }
        // 노치 자체에 바로 놓아도 드롭이 성사된다.
        tracker.onFilesDropped = { [weak self] urls in
            ChapDrop.store(urls)
            self?.hidePanel()
        }
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

        let slots = slotsProvider()
        guard !slots.isEmpty else { return }

        // 노치보다 넓게 잡아야 "노치가 자라난" 실루엣이 된다.
        // 최종 폭은 가로로 배치된 섹션 수에 따라 자연 크기로 커진다.
        let inset = screen.safeAreaInsets.top
        let notchWidth = Self.notchRect(on: screen).width
        let minWidth = max(notchWidth + 80, Self.panelMinWidth)

        let reveal = NotchRevealModel()
        reveal.bottomOpacity = opacityProvider()
        reveal.colorHex = colorProvider()
        let content = NotchLauncherPanelView(
            minWidth: minWidth,
            topInset: inset,
            stripPlateauHalfWidth: Self.stripPlateauHalfWidth(on: screen),
            style: styleProvider(),
            slots: slots,
            onLaunch: { [weak self] siteIndex in
                self?.hidePanel()
                self?.onLaunch(siteIndex)
            },
            reveal: reveal)
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

        // 등장: Dynamic Island처럼 노치에서 bouncy 스프링으로 펼친다.
        panel.orderFrontRegardless()
        // 메인 패널 위에는 배지를 앞에 둔다. 배지로 마우스를 옮기면
        // Drop 파일 도커로 전환할 수 있어야 하기 때문이다.
        badgeWindow?.order(.above, relativeTo: panel.windowNumber)
        self.panel = panel
        self.activeSurface = .mainPanel
        self.revealModel = reveal
        DispatchQueue.main.async {
            withAnimation(NotchLauncherPanelView.openAnimation) {
                reveal.revealed = true
            }
        }
        startVisibilityMonitor()
    }

    // MARK: - Drop panel

    /// Drop 배지 hover로 여는 파일 도커. 배지 span이 최소, 메인 도커 폭이 최대다.
    private func showDropPanel() {
        guard panel == nil, let screen = Self.notchScreen() else { return }
        presentDropDock(
            content: NotchDropPanelView(
                topInset: screen.safeAreaInsets.top,
                minContentWidth: Self.dropDockContentWidth(on: screen),
                maxContentWidth: mainDockContentWidth(on: screen),
                bottomOpacity: opacityProvider(),
                colorHex: colorProvider(),
                stripPlateauHalfWidth: Self.stripPlateauHalfWidth(on: screen),
                onSizeChange: { [weak self] size in self?.resizeDropDock(to: size) }),
            on: screen)
    }

    /// 열려 있는 Drop 도커의 창을 콘텐츠 크기에 맞춰 같은 앵커
    /// (노치 중앙, 상단 밀착)로 리사이즈한다.
    private func resizeDropDock(to size: CGSize) {
        guard let panel, activeSurface == .dropDock,
            let screen = Self.notchScreen()
        else { return }
        let notch = Self.notchRect(on: screen)
        var frame = NSRect(
            x: notch.midX - ceil(size.width) / 2,
            y: screen.frame.maxY - ceil(size.height),
            width: ceil(size.width), height: ceil(size.height)
        ).integral
        frame.origin.y = screen.frame.maxY - frame.height
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
    }

    /// 메인 런처 도커의 콘텐츠 폭 추정치. Drop 파일 도커의 폭 상한으로 쓴다.
    private func mainDockContentWidth(on screen: NSScreen) -> CGFloat {
        let slotCount = max(slotsProvider().count, 1)
        let black =
            CGFloat(slotCount) * NotchLauncherPanelView.columnWidth
            + CGFloat(slotCount - 1) * DS.spacing + DS.padding * 2
        return max(black - DS.paddingSmall * 2, Self.dropDockContentWidth(on: screen))
    }

    /// 눌린 검정 띠의 plateau 반폭: 노치 반폭 + 배지 폭.
    /// 이 구간까지는 검정이 평평하게 깊고, 바깥에서 곡선으로 얇아진다.
    private static func stripPlateauHalfWidth(on screen: NSScreen) -> CGFloat {
        notchRect(on: screen).width / 2 + NotchGeometry.badgeBodyWidth
    }

    /// Drop 도커의 콘텐츠 폭. 노치 좌우로 배지 폭만큼 대칭 확장한 구간을
    /// 덮는다 (왼쪽 Drop 배지 + 추후 우측 배지 자리). 도커는 노치 중앙 정렬.
    ///
    /// NotchDockShape의 상단 오목 플레어가 좌우 topCornerRadius만큼 벽을
    /// 안쪽으로 들이므로, 보이는 벽이 배지 바깥 변에 오도록 그만큼 더한다.
    private static func dropDockContentWidth(on screen: NSScreen) -> CGFloat {
        let notch = notchRect(on: screen)
        // 배지 본체 폭만큼 좌우 대칭으로 더해, 배지 폭이 바뀌면 도커도 따라간다.
        let badgeExtension = NotchGeometry.badgeBodyWidth
        let flareInset = NotchDropDock.topCornerRadius * 2
        return notch.width + badgeExtension * 2 + flareInset - DS.paddingSmall * 2
    }

    /// Drop 도커 공통 표시. 노치 중앙에 정렬하고, 떠 있는 동안 배지를
    /// 숨겨 도커 밖으로 배지가 튀어나오지 않게 한다.
    private func presentDropDock<Content: View>(content: Content, on screen: NSScreen) {
        let hosting = NSHostingView(rootView: content)
        hosting.safeAreaRegions = []
        let fitting = hosting.fittingSize
        let size = CGSize(width: ceil(fitting.width), height: ceil(fitting.height))

        // 노치 중앙 정렬. 좌우 배지 확장 폭이 대칭이라 배지도 함께 덮인다.
        let notch = Self.notchRect(on: screen)
        var frame = NSRect(
            x: notch.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width, height: size.height
        ).integral
        frame.origin.y = screen.frame.maxY - frame.height

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = hosting

        panel.orderFrontRegardless()
        // Drop 도커 위에서도 배지는 앞에 남는다. 도커 상단 띠와 같은 검정이라
        // 겹쳐도 이음새가 없고, 노치 hover로 되돌아가는 왕복 전환의 기준점이 된다.
        badgeWindow?.order(.above, relativeTo: panel.windowNumber)
        self.panel = panel
        self.activeSurface = .dropDock
        startVisibilityMonitor()
    }

    // MARK: - Drop zone

    /// 파일 드래그가 노치에 닿았을 때 여는 드롭 존.
    /// Drop 리스트 도커와 같은 크기·앵커를 쓴다.
    /// 전체 런처 패널이 이미 떠 있으면 그대로 둔다 (Drop 위젯이 받는다).
    private func showDropZone() {
        guard panel == nil, let screen = Self.notchScreen() else { return }

        let content = NotchDropZoneView(
            topInset: screen.safeAreaInsets.top,
            contentWidth: Self.dropDockContentWidth(on: screen),
            bottomOpacity: opacityProvider(),
            colorHex: colorProvider(),
            stripPlateauHalfWidth: Self.stripPlateauHalfWidth(on: screen),
            onDropped: { [weak self] in self?.hidePanel() })
        presentDropDock(content: content, on: screen)
    }

    // MARK: - Opacity preview

    /// 설정 슬라이더 드래그 시작. 패널을 띄워 고정하고 실시간 값을 보여준다.
    func beginOpacityPreview() {
        isPreviewPinned = true
        if panel == nil { showPanel() }
        revealModel?.bottomOpacity = opacityProvider()
    }

    /// 드래그 중 값 변경을 즉시 반영한다.
    func updateOpacityPreview(_ value: Double) {
        revealModel?.bottomOpacity = value
    }

    /// 드래그 종료. 고정을 풀면 일반 규칙(마우스 위치)으로 닫힌다.
    func endOpacityPreview() {
        isPreviewPinned = false
        lastInsideDate = Date()
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
        // 프리뷰 고정 중에는 마우스 위치와 무관하게 유지한다.
        if isPreviewPinned {
            lastInsideDate = Date()
            return
        }
        let location = NSEvent.mouseLocation
        // 표면 전환은 이벤트가 아니라 폴링으로 판정한다. 핫존 창이 도커
        // 아래에 깔리면 mouseEntered가 가려져 오지 않기 때문이다.
        if switchSurfaceIfNeeded(at: location) { return }
        var stayRegion = panel.frame.union(hotzoneWindow?.frame ?? panel.frame)
        if let badgeFrame = badgeWindow?.frame {
            stayRegion = stayRegion.union(badgeFrame)
        }
        stayRegion = stayRegion.insetBy(dx: -Self.dwellMargin, dy: -Self.dwellMargin)
        if stayRegion.contains(location) {
            lastInsideDate = Date()
            return
        }
        if Date().timeIntervalSince(lastInsideDate) >= Self.hideDelay {
            hidePanel()
        }
    }

    /// 표면 전환용 즉시 정리. 애니메이션 없이 현재 패널을 내린다.
    private func dismissPanelImmediately() {
        stopVisibilityMonitor()
        panel?.orderOut(nil)
        panel = nil
        activeSurface = nil
        revealModel = nil
    }

    /// 마우스가 배지 위로 오면 메인 도커를 Drop 도커로 전환한다.
    /// 전환했으면 true (현재 폴링 사이클은 종료).
    /// 역방향(노치 hover로 메인 복귀)은 드롭존과 충돌해 두지 않는다 —
    /// Drop 도커는 영역을 벗어나 닫은 뒤 노치 hover로 다시 연다.
    private func switchSurfaceIfNeeded(at location: NSPoint) -> Bool {
        // 드래그(버튼 눌림) 중에는 전환하지 않는다.
        guard NSEvent.pressedMouseButtons == 0 else { return false }
        // 배지 위: 메인 도커 → Drop 도커.
        if activeSurface == .mainPanel, let badgeZone = badgeWindow?.frame,
            badgeZone.contains(location)
        {
            dismissPanelImmediately()
            showDropPanel()
            return true
        }
        return false
    }

    private func hidePanel() {
        stopVisibilityMonitor()
        guard let panel else { return }
        self.panel = nil
        self.activeSurface = nil
        // 모든 도커가 같은 시간에 사라진다: 메인 패널은 노치로 말려 들어가고,
        // reveal 모델이 없는 Drop 도커들은 같은 길이의 페이드로 정리한다.
        if let reveal = revealModel {
            withAnimation(NotchLauncherPanelView.closeAnimation) {
                reveal.revealed = false
            }
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NotchLauncherPanelView.closeDuration
                panel.animator().alphaValue = 0
            }
        }
        revealModel = nil
        DispatchQueue.main.asyncAfter(
            deadline: .now() + NotchLauncherPanelView.closeDuration + 0.02
        ) { [weak self] in
            panel.orderOut(nil)
            self?.updateDropBadge()
        }
    }
}

/// mouseEntered 콜백과 파일 드래그 진입 콜백을 제공하는 추적 뷰.
/// 파일을 끌고 있는 동안에는 tracking area가 발화하지 않으므로,
/// 드롭 존으로 쓰려면 드래그 진입도 패널 열기 신호로 받아야 한다.
private final class HoverView: NSView {
    var onEntered: () -> Void = {}
    var onDragEntered: () -> Void = {}
    /// 설정 시 이 뷰 자체가 드롭 타깃이 된다. 드롭존 도커가 아직 뜨기 전에
    /// 배지·노치 위에 바로 놓아도 드롭이 성사되게 한다.
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

    /// 파일 드래그가 노치 위로 들어오면 컴팩트 드롭 존을 노출한다.
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered()
        return onFilesDropped != nil ? .copy : []
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
