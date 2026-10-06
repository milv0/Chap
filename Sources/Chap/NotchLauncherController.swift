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
    /// 패널이 닫히기 직전. 메모처럼 입력 중인 위젯이 남은 변경을 저장한다.
    static let willHidePanel = Notification.Name("ChapNotchWillHidePanel")
    /// 도커 안을 클릭했다. userInfo["point"]는 SwiftUI 좌표(창 왼쪽 위 원점)의 CGPoint.
    /// point가 없으면 패널이 key를 잃은 것으로, 열린 띠 팝업을 무조건 접는다.
    static let didClickPanel = Notification.Name("ChapNotchDidClickPanel")
    /// 공유 메뉴 같은 시스템 팝업이 떠 있는 동안 도커를 고정/해제한다. object는 Bool(고정 여부).
    static let setSharingPinned = Notification.Name("ChapNotchSetSharingPinned")
    /// 도커 안 UI(메모 분리 등)가 도커를 닫아 달라고 요청한다.
    static let requestClose = Notification.Name("ChapNotchRequestClose")

    private var hotzoneWindow: NSWindow?
    private var panel: NSPanel?
    private var badgeWindow: NSWindow?
    /// 드롭 완료 직후에는 hover로 메인 도커를 열지 않는다. 드래그가 끝나는
    /// 순간 tracking이 재개되며 mouseEntered가 곧바로 날아오기 때문이다.
    private var hoverOpenSuppressedUntil = Date.distantPast
    /// Glass appearance 선택 후 메인 도커를 잠깐 고정하는 프리뷰 토큰.
    private var appearancePreviewToken = 0
    /// 비동기 배지 count 중 오래된 결과를 버리는 generation.
    private var badgeRefreshToken = 0
    /// opacity 드래그 pin의 self-healing 토큰.
    private var opacityPreviewToken = 0
    private var dropObserver: NSObjectProtocol?
    private var visibilityTimer: Timer?
    private var lastInsideDate = Date()
    /// 현재 패널의 펼침/불투명도 모델. 패널이 없으면 nil.
    private var revealModel: NotchRevealModel?
    private var escapeMonitor: Any?
    private var clickMonitor: Any?
    private var resignKeyObserver: NSObjectProtocol?
    /// 설정 슬라이더 프리뷰 중에는 자동 숨김을 멈추고 패널을 고정한다.
    private var isPreviewPinned = false
    /// 공유 메뉴가 떠 있는 동안: 마우스가 밖으로 나가도 닫지 않는다.
    private var isSharingPinned = false
    private var sharingPinObserver: NSObjectProtocol?
    private var closeRequestObserver: NSObjectProtocol?

    /// 패널에 표시할 위젯 칸 공급자. 항상 최신 config 기준으로 재계산된다.
    var slotsProvider: () -> [NotchSlotContent] = { [] }
    /// 상단 띠 Mirror 아이콘 표시 여부.
    var mirrorEnabledProvider: () -> Bool = { false }
    /// 상단 띠 Quick Note 아이콘 표시 여부.
    var quickNoteEnabledProvider: () -> Bool = { false }
    /// 패널 시각 스타일 공급자.
    var styleProvider: () -> NotchPanelStyle = { .custom }
    /// Liquid Glass System/Light/Dark appearance 공급자.
    var glassAppearanceProvider: () -> NotchGlassAppearance = { .system }
    /// Apple 공식 Liquid Glass Clear/Regular 재질 공급자.
    var glassMaterialProvider: () -> NotchGlassMaterial = { .clear }
    /// 패널 하단 불투명도 공급자.
    var opacityProvider: () -> Double = { Config.notchPanelOpacityDefault }
    /// 콘텐츠 박스 배경색 공급자 ("#RRGGBB").
    var colorProvider: () -> String = { Config.notchPanelColorHexDefault }
    /// Keep Awake 세션 종료 시각 공급자. 메인 도커의 남은 시간 표시에 쓴다.
    var awakeSessionEndProvider: () -> Date? = { nil }
    /// 항목 실행 콜백. `config.sites` 원본 인덱스를 넘긴다.
    var onLaunch: (Int) -> Void = { _ in }
    /// 런처 칸 제목 클릭 → 해당 타입이 선택된 설정창.
    var onOpenSettings: (LaunchType) -> Void = { _ in }
    /// 어깨로 접힌 위젯 공급자와 변경 콜백 (config 저장).
    var collapsedWidgetsProvider: () -> [NotchWidget] = { [] }
    var onCollapsedChange: ([NotchWidget]) -> Void = { _ in }

    /// (개발용) Debug 빌드에서만 어깨 경계선을 그린다.
    /// 켜기: `defaults write com.mingyupark.Chap ChapShowShoulderGuides -bool YES`
    static var showsShoulderGuides: Bool {
        #if DEBUG
            return UserDefaults.standard.bool(forKey: "ChapShowShoulderGuides")
        #else
            return false
        #endif
    }

    /// 배지는 메인 패널보다 한 단계 높은 고정 레벨. 같은 `.statusBar`이면
    /// 패널 클릭 시 AppKit이 패널을 앞으로 재정렬해 배지를 덮을 수 있다.
    private static let badgeLevel = NSWindow.Level(
        rawValue: NSWindow.Level.statusBar.rawValue + 1)
    /// 노치·패널 밖에서 이 시간 이상 머물면 닫는다.
    private static let hideDelay: TimeInterval = 0.2
    private static let pollInterval: TimeInterval = 0.08
    /// 경계에서의 미세한 좌표 흔들림으로 닫히지 않도록 주는 여유.
    private static let dwellMargin: CGFloat = 6

    /// 토글/노치 유무에 따라 핫존을 켜거나 끈다. 조건이 안 되면 전부 내린다.
    /// 열린 도커 창을 SwiftUI가 잰 콘텐츠 크기에 맞춘다 (메모 모드 전환 등).
    /// 상단은 항상 화면 최상단에 붙인다. 계산은 `showPanel`과 같은 규칙을 쓴다.
    private func resizePanel(toContentSize size: CGSize) {
        guard panel != nil, size.height > 0 else { return }
        pendingShrink?.cancel()
        pendingShrink = nil
        let steps = NotchLauncherPolicy.resizeSteps(
            current: appliedContentSize ?? size, target: size)
        if let now = steps.immediate { applyPanelContentSize(now) }
        if appliedContentSize == nil { appliedContentSize = size }
        guard let later = steps.deferred else { return }
        let work = DispatchWorkItem { [weak self] in self?.applyPanelContentSize(later) }
        pendingShrink = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + NotchLauncherPolicy.shrinkDelay, execute: work)
    }

    /// 칸을 펼치기 직전에 창을 미리 넓힌다. 미뤄 둔 축소가 있으면 취소한다.
    private func preparePanelToGrow(byWidth added: CGFloat) {
        guard let current = appliedContentSize else { return }
        pendingShrink?.cancel()
        pendingShrink = nil
        applyPanelContentSize(
            NotchLauncherPolicy.preExpandSize(
                current: current, slotWidth: added, gap: 0))
    }

    /// 마지막으로 창에 맞춘 콘텐츠 크기와, 애니메이션 뒤로 미룬 축소 작업.
    private var appliedContentSize: CGSize?
    private var pendingShrink: DispatchWorkItem?

    private func applyPanelContentSize(_ size: CGSize) {
        appliedContentSize = size
        guard let panel, let screen = Self.notchScreen() else { return }
        let inset = screen.safeAreaInsets.top
        var frame = NotchLauncherPolicy.panelFrame(
            screenFrame: screen.frame,
            topSafeAreaInset: inset,
            contentSize: CGSize(width: ceil(size.width), height: ceil(size.height) - inset))
        frame = frame.integral
        frame.origin.y = screen.frame.maxY - frame.height
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        lastInsideDate = Date()
    }

    func update(enabled: Bool) {
        guard let screen = Self.notchScreen(),
            NotchLauncherPolicy.shouldPresent(
                enabled: enabled, topSafeAreaInset: screen.safeAreaInsets.top)
        else {
            tearDown()
            return
        }
        installHotzone(on: screen)
        applyGlassAppearance(to: panel)
        installDropObserverIfNeeded()
        updateDropBadge()
    }

    func tearDown() {
        prepareForPanelHide()
        stopVisibilityMonitor()
        badgeRefreshToken += 1
        isPreviewPinned = false
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

    /// 보관함 파일 수에 따라 노치 오른쪽 Drop 배지 도커를 갱신한다.
    private func updateDropBadge() {
        badgeRefreshToken += 1
        let token = badgeRefreshToken
        ChapDrop.fileCountAsync { [weak self] count in
            guard let self, self.badgeRefreshToken == token else { return }
            self.renderDropBadge(count: count)
        }
    }

    private func renderDropBadge(count: Int) {
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
        // 배지 hover는 메인 도커를, 파일 드래그는 Drop here overlay를 연다.
        tracker.onEntered = { [weak self] in
            guard let self, Date() >= self.hoverOpenSuppressedUntil else { return }
            self.showPanel()
        }
        tracker.onDragEntered = { [weak self] in self?.presentDropOverlay() }
        tracker.onDragExited = { [weak self] in
            self?.revealModel?.isDropTargetActive = false
        }
        // 드롭존 도커가 뜨기 전에 배지 위에 바로 놓아도 드롭이 성사된다.
        tracker.onFilesDropped = { [weak self] urls in
            self?.storeDroppedFiles(urls, closePanelWhenDone: true)
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
        window.level = Self.badgeLevel
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

    /// 파일 복사는 utility queue에서 수행하고 실패 건수는 사용자에게 알린다.
    private func storeDroppedFiles(_ urls: [URL], closePanelWhenDone: Bool) {
        guard !urls.isEmpty else { return }
        hoverOpenSuppressedUntil = Date().addingTimeInterval(0.8)
        ChapDrop.storeAsync(urls) { [weak self] _, failedCount in
            if failedCount > 0 {
                LauncherUtils.showAlert(
                    message: "Some files could not be added",
                    info: "\(failedCount) item(s) could not be copied to Chap Drop.")
            }
            if closePanelWhenDone { self?.hidePanel() }
        }
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
        // 마우스 hover는 메인 패널을, 파일 드래그는 Drop here overlay를 연다.
        tracker.onEntered = { [weak self] in
            guard let self, Date() >= self.hoverOpenSuppressedUntil else { return }
            self.showPanel()
        }
        tracker.onDragEntered = { [weak self] in self?.presentDropOverlay() }
        tracker.onDragExited = { [weak self] in
            self?.revealModel?.isDropTargetActive = false
        }
        // 노치 자체에 바로 놓아도 드롭이 성사된다.
        tracker.onFilesDropped = { [weak self] urls in
            self?.storeDroppedFiles(urls, closePanelWhenDone: true)
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

    /// 눌린 검정 띠의 plateau 반폭: 노치 반폭 + 좌우 상태 영역.
    /// 상태 영역의 바깥 모서리에서 곧바로 상단 띠가 줄기 시작한다.
    private static func stripPlateauHalfWidth(on screen: NSScreen) -> CGFloat {
        notchRect(on: screen).width / 2 + NotchGeometry.stripPlateauSideWidth
    }

    // MARK: - Panel

    private func showPanel(forDrop: Bool = false) {
        guard panel == nil, let screen = Self.notchScreen() else { return }

        let slots = slotsProvider()
        guard
            NotchLauncherPolicy.shouldBuildPanel(
                hasSlots: !slots.isEmpty || mirrorEnabledProvider()
                    || quickNoteEnabledProvider(), forDrop: forDrop)
        else { return }

        // 노치보다 넓게 잡아야 "노치가 자라난" 실루엣이 된다.
        // 최종 폭은 가로로 배치된 섹션 수에 따라 자연 크기로 커진다.
        let inset = screen.safeAreaInsets.top
        let notchWidth = Self.notchRect(on: screen).width
        let minWidth = NotchLauncherPolicy.dockMinWidth(notchWidth: notchWidth)

        let reveal = NotchRevealModel()
        reveal.bottomOpacity = opacityProvider()
        reveal.colorHex = colorProvider()
        reveal.collapsedWidgets = collapsedWidgetsProvider()
        let content = NotchLauncherPanelView(
            minWidth: minWidth,
            topInset: inset,
            stripPlateauHalfWidth: Self.stripPlateauHalfWidth(on: screen),
            awakeSessionEnd: awakeSessionEndProvider(),
            style: styleProvider(),
            glassMaterial: glassMaterialProvider(),
            slots: slots,
            showsMirror: mirrorEnabledProvider(),
            showsNote: quickNoteEnabledProvider(),
            onLaunch: { [weak self] siteIndex in
                self?.hidePanel()
                self?.onLaunch(siteIndex)
            },
            onContentSizeChange: { [weak self] size in
                // 레이아웃이 끝난 뒤 불리지만, 창 조정은 다음 틱으로 미뤄 레이아웃 중 재진입을 피한다.
                DispatchQueue.main.async { self?.resizePanel(toContentSize: size) }
            },
            onOpenSettings: { [weak self] type in
                self?.hidePanel()
                self?.onOpenSettings(type)
            },
            onCollapsedChange: { [weak self] widgets in
                self?.onCollapsedChange(widgets)
            },
            onPrepareExpand: { [weak self] added in
                self?.preparePanelToGrow(byWidth: added)
            },
            showsShoulderGuides: Self.showsShoulderGuides,
            reveal: reveal)
        let hosting = NSHostingView(rootView: content)
        // 노치 구간 safe area가 콘텐츠를 아래로 밀지 않게 한다.
        hosting.safeAreaRegions = []
        // fittingSize에는 노치 감싸기용 top padding이 이미 포함되어 있으므로
        // 정책에는 콘텐츠 높이만 전달해 inset이 두 번 더해지지 않게 한다.
        // 소수점 크기는 올림해 상단이 서브픽셀로 내려앉는 틈을 막는다.
        let fitting = hosting.fittingSize
        let size = CGSize(width: ceil(fitting.width), height: ceil(fitting.height))
        appliedContentSize = size
        var frame = NotchLauncherPolicy.panelFrame(
            screenFrame: screen.frame,
            topSafeAreaInset: inset,
            contentSize: CGSize(width: size.width, height: size.height - inset))
        // 픽셀 정렬 후에도 상단 변이 정확히 화면 최상단에 오도록 y를 재고정한다.
        frame = frame.integral
        frame.origin.y = screen.frame.maxY - frame.height

        let panel = NotchKeyablePanel(
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
        applyGlassAppearance(to: panel)
        panel.contentView = hosting

        // 등장: Dynamic Island처럼 노치에서 bouncy 스프링으로 펼친다.
        panel.orderFrontRegardless()
        // 메인 패널 위에는 배지를 앞에 둔다. 배지로 마우스를 옮기면
        // Drop 파일 도커로 전환할 수 있어야 하기 때문이다.
        badgeWindow?.order(.above, relativeTo: panel.windowNumber)
        self.panel = panel
        self.revealModel = reveal
        DispatchQueue.main.async {
            withAnimation(NotchLauncherPanelView.openAnimation) {
                reveal.revealed = true
            }
        }
        startVisibilityMonitor()
    }

    /// 파일 드래그가 노치에 닿으면 메인 도커를 열고 그 위에
    /// 반투명 "Drop here" 레이어를 덮는다.
    private func presentDropOverlay() {
        if panel == nil { showPanel(forDrop: true) }
        revealModel?.isDropTargetActive = true
    }

    /// Glass 스타일의 창 appearance를 적용한다. System은 nil로 두어 macOS
    /// 변경을 실시간으로 따르고, Light/Dark는 이 NSPanel에만 강제한다.
    private func applyGlassAppearance(to panel: NSPanel?) {
        guard let panel else { return }
        guard styleProvider() == .glass else {
            panel.appearance = nil
            return
        }
        switch glassAppearanceProvider() {
        case .system:
            panel.appearance = nil
        case .light:
            panel.appearance = NSAppearance(named: .aqua)
        case .dark:
            panel.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Settings preview

    /// Glass System/Light/Dark 선택 직후 메인 도커를 펼쳐 일정 시간 고정한다.
    /// 연속 선택 시 마지막 토큰만 고정을 해제한다.
    func previewGlassAppearance() {
        // appearance는 Glass 뷰 생성 시점에 적용되므로 패널을 재구성한다.
        beginTimedPanelPreview(rebuildPanel: true)
        applyGlassAppearance(to: panel)
    }

    /// Glass Clear/Regular 선택 직후 메인 도커를 새 재질로 다시 만들어 보여준다.
    /// 재질은 뷰 생성 값이라 이미 열린 패널은 재구성해야 한다.
    func previewGlassMaterial() {
        beginTimedPanelPreview(rebuildPanel: true)
    }

    /// Custom 색 변경을 열린 메인 도커에 즉시 반영하고 잠깐 고정한다.
    func previewCustomColor(_ colorHex: String) {
        beginTimedPanelPreview(rebuildPanel: false)
        revealModel?.colorHex = colorHex
    }

    private func beginTimedPanelPreview(rebuildPanel: Bool) {
        isPreviewPinned = true
        appearancePreviewToken += 1
        let token = appearancePreviewToken
        if rebuildPanel, panel != nil { dismissPanelImmediately() }
        if panel == nil { showPanel() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.appearancePreviewToken == token else { return }
            self.isPreviewPinned = false
            self.lastInsideDate = Date()
        }
    }

    // MARK: - Opacity preview

    /// 설정 슬라이더 드래그 시작. 패널을 띄워 고정하고 실시간 값을 보여준다.
    func beginOpacityPreview() {
        isPreviewPinned = true
        opacityPreviewToken += 1
        let token = opacityPreviewToken
        if panel == nil { showPanel() }
        revealModel?.bottomOpacity = opacityProvider()
        // SwiftUI가 slider의 editing=false를 잃어도 영구 pin되지 않게 한다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self, self.opacityPreviewToken == token else { return }
            self.isPreviewPinned = false
            self.lastInsideDate = Date()
        }
    }

    /// 드래그 중 값 변경을 즉시 반영한다.
    func updateOpacityPreview(_ value: Double) {
        revealModel?.bottomOpacity = value
    }

    /// 드래그 종료. 고정을 풀면 일반 규칙(마우스 위치)으로 닫힌다.
    func endOpacityPreview() {
        opacityPreviewToken += 1
        isPreviewPinned = false
        lastInsideDate = Date()
    }

    /// 마우스가 노치·패널을 벗어난 채 `hideDelay`를 넘기면 닫는다.
    private func startVisibilityMonitor() {
        stopVisibilityMonitor()
        startEscapeMonitor()
        startOutsideClickMonitor()
        startSharingPinObserver()
        lastInsideDate = Date()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.evaluateVisibility()
        }
        RunLoop.main.add(timer, forMode: .common)
        visibilityTimer = timer
    }

    private func stopVisibilityMonitor() {
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        stopEscapeMonitor()
    }

    /// 패널이 key일 때 Esc로 닫는다 (메모 입력 중 빠져나오는 길).
    private func startEscapeMonitor() {
        stopEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, event.keyCode == 53, let panel = self.panel,
                event.window === panel
            else { return event }
            self.hidePanel()
            return nil
        }
    }

    private func stopEscapeMonitor() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        if let resignKeyObserver { NotificationCenter.default.removeObserver(resignKeyObserver) }
        resignKeyObserver = nil
        if let sharingPinObserver { NotificationCenter.default.removeObserver(sharingPinObserver) }
        sharingPinObserver = nil
        if let closeRequestObserver {
            NotificationCenter.default.removeObserver(closeRequestObserver)
        }
        closeRequestObserver = nil
        isSharingPinned = false
    }

    /// 띠 팝업(Quick Note·Mirror) 바깥을 누르거나 다른 앱을 누르면 팝업을 접게 알린다.
    /// 클릭 이벤트는 그대로 흘려보내 아래 위젯도 평소처럼 반응한다.
    private func startSharingPinObserver() {
        closeRequestObserver = NotificationCenter.default.addObserver(
            forName: Self.requestClose, object: nil, queue: .main
        ) { [weak self] _ in
            self?.hidePanel()
        }
        sharingPinObserver = NotificationCenter.default.addObserver(
            forName: Self.setSharingPinned, object: nil, queue: .main
        ) { [weak self] note in
            self?.isSharingPinned = (note.object as? Bool) ?? false
            self?.lastInsideDate = Date()
        }
    }

    private func startOutsideClickMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
            [weak self] event in
            guard let self, let panel = self.panel, event.window === panel,
                let content = panel.contentView
            else { return event }
            let location = event.locationInWindow
            let point = CGPoint(x: location.x, y: content.bounds.height - location.y)
            NotificationCenter.default.post(
                name: Self.didClickPanel, object: self, userInfo: ["point": point])
            return event
        }
        guard let panel else { return }
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            NotificationCenter.default.post(name: Self.didClickPanel, object: self)
        }
    }

    /// 닫히기 직전 공통 정리: 카메라를 끄고 입력 중인 메모를 저장하게 한다.
    private func prepareForPanelHide() {
        pendingShrink?.cancel()
        pendingShrink = nil
        appliedContentSize = nil
        NotificationCenter.default.post(name: Self.willHidePanel, object: self)
        MirrorCamera.shared.stop()
    }

    private func evaluateVisibility() {
        guard let panel else {
            stopVisibilityMonitor()
            return
        }
        // ⌥ 상태는 앱이 비활성이어도 읽을 수 있는 전역 modifierFlags로 확인한다.
        // (nonactivating 패널에는 flagsChanged 이벤트가 오지 않고, 전역 키 모니터는 권한이 필요하다.)
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if let reveal = revealModel, reveal.isOptionHeld != optionHeld {
            reveal.isOptionHeld = optionHeld
        }
        // 프리뷰 고정 중에는 마우스 위치와 무관하게 유지한다.
        if isPreviewPinned || isSharingPinned {
            lastInsideDate = Date()
            return
        }
        // 빠른 메모를 입력하는 동안에는 마우스가 벗어나도 닫지 않는다.
        // 다른 곳을 클릭해 패널이 key를 잃거나 Esc를 누르면 평소 규칙으로 돌아간다.
        if panel.isKeyWindow, panel.firstResponder is NSTextView {
            lastInsideDate = Date()
            return
        }
        let location = NSEvent.mouseLocation
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
        if panel != nil { prepareForPanelHide() }
        stopVisibilityMonitor()
        panel?.orderOut(nil)
        panel = nil
        revealModel = nil
    }

    private func hidePanel() {
        stopVisibilityMonitor()
        guard let panel else { return }
        prepareForPanelHide()
        self.panel = nil
        // 메인 패널을 노치로 말아 넣고 애니메이션 뒤 창을 정리한다.
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
    var onDragExited: () -> Void = {}
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

    /// 파일 드래그가 노치 위로 들어오면 메인 패널의 Drop here overlay를 노출한다.
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

/// 메인 도커 패널. borderless 패널은 기본적으로 key가 될 수 없어 빠른 메모에
/// 입력할 수 없으므로 key를 허용한다. `.nonactivatingPanel`이라 key가 되어도
/// 앞의 앱을 비활성화하지 않고, `becomesKeyOnlyIfNeeded`로 입력 칸을 누를 때만 key가 된다.
final class NotchKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
