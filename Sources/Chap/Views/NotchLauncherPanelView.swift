import Combine
import SwiftUI

/// 노치 아래에 펼쳐지는 런처 목록. 상태바 메뉴와 같은
/// `LauncherListPolicy` 결과를 그대로 렌더링한다.
///
/// 시각 언어는 "노치 확장"이다: 순수 검정 배경이 노치와 이어지고,
/// 하단 모서리만 둥글어 노치가 아래로 자라난 것처럼 보인다.
/// 검정 위 텍스트라 라이트/다크 모드와 무관하게 흰색 계열을 고정한다.
struct NotchLauncherPanelView: View {
    /// 패널 최소 폭 (노치 폭 + 여유). 섹션이 많으면 자연 폭으로 더 넓어진다.
    let minWidth: CGFloat
    /// 상단바(노치) 구간 높이. 이만큼 검정이 위로 연장되어 노치를 감싼다.
    let topInset: CGFloat
    /// 눌린 검정 띠의 plateau 반폭 (노치 반폭 + 좌우 상태 영역).
    let stripPlateauHalfWidth: CGFloat
    /// Keep Awake 세션 종료 시각. 활성 중이면 왼쪽 상단 영역에 h:mm:ss로 표시.
    /// 도커를 열 때의 Keep Awake 종료 시각. 이후 변화는 `liveAwakeSessionEnd`가 따라간다.
    let awakeSessionEnd: Date?
    /// 도커가 열린 동안 Focus·메뉴에서 켜고 끈 결과를 바로 반영하는 종료 시각.
    /// nil은 "아직 알림 없음"(= 열 때 값 사용), .some(nil)은 "꺼짐"이다.
    @State private var liveAwakeSessionEnd: Date??
    @Environment(\.colorScheme) private var colorScheme
    private var currentAwakeSessionEnd: Date? { liveAwakeSessionEnd ?? awakeSessionEnd }
    /// 시각 스타일. Custom은 색상·불투명도 도크, Glass는 시스템 재질.
    let style: NotchPanelStyle
    /// Apple 공식 Glass.clear/regular 재질 변형.
    let glassMaterial: NotchGlassMaterial
    /// 배치된 위젯 칸들 (빈 칸 제외, 왼쪽부터).
    let slots: [NotchSlotContent]
    /// 상단 검정 띠에 Mirror 아이콘을 둘지. Drop 배지 오른쪽, 배지가 없으면 배지 자리에 둔다.
    var showsMirror = false
    /// 상단 검정 띠에 Quick Note 아이콘을 둘지. Mirror 오른쪽에 둔다.
    var showsNote = false
    /// 상단 검정 띠에 Cover Screens 아이콘을 둘지. Quick Note 오른쪽에 둔다.
    var showsCoverScreens = false
    let onLaunch: (Int) -> Void
    /// 저장된 Layout을 연다.
    var onOpenLayout: (UUID) -> Void = { _ in }
    /// 현재 앱 창 배치를 새 Layout으로 캡처한다.
    var onCaptureLayout: () -> Void = {}
    /// 저장된 Layout을 지운다(확인 창을 거친다).
    var onRemoveLayout: (UUID) -> Void = { _ in }
    /// 저장된 Layout을 고치는 창을 연다.
    var onEditLayout: (UUID) -> Void = { _ in }
    /// Layouts 칸 제목 클릭.
    var onOpenLayoutSettings: () -> Void = {}
    /// 지금 열리는 중인 Layout을 알려 주는 공급자(열릴 때마다 읽는다).
    var busyLayoutIDProvider: () -> UUID? = { nil }
    /// 도커를 열 때 돌고 있는 타이머가 끝나는 시각. 이후 변화는 Focus 칸이 알림으로 받는다.
    var timerEndProvider: () -> Date? = { nil }
    /// 실제 레이아웃이 끝난 도커 크기(그림자 여백 포함). 칸을 접는 등 내용이 바뀌면
    /// 컨트롤러가 이 값으로 창을 다시 맞춘다. 타이밍 추측 없이 SwiftUI가 잰 값을 쓴다.
    var onContentSizeChange: (CGSize) -> Void = { _ in }
    /// 런처 칸 제목을 누르면 그 타입이 선택된 설정창을 연다.
    var onOpenSettings: (LaunchType) -> Void = { _ in }
    /// 칸을 접거나 펼쳤을 때 새 목록. 컨트롤러가 config에 저장한다.
    var onCollapsedChange: ([NotchWidget]) -> Void = { _ in }
    /// 칸을 펼치기 직전, 늘어날 폭(칸 폭 + 간격)만큼 창을 미리 넓혀 달라는 요청.
    var onPrepareExpand: (CGFloat) -> Void = { _ in }
    /// (개발용) 어깨·곡선 구간 경계선을 그린다. 렌더 도구와 Debug 빌드의
    /// `ChapShowShoulderGuides` 기본값으로만 켠다 (Release에서는 항상 꺼짐).
    var showsShoulderGuides = false
    @ObservedObject var reveal: NotchRevealModel

    /// 원래의 모션: 패널 전체가 노치 상단 기준으로 스프링 확장하고,
    /// 접힘은 빠른 페이드로 정리한다. stiffness 440은 약 0.3초에 정착하고,
    /// damping 30은 기존(320/26)과 같은 감쇠 비율이라 바운스 느낌은 유지된다.
    static let openAnimation: Animation = .interpolatingSpring(stiffness: 440, damping: 30)
    /// 모든 도커가 공유하는 닫힘 시간. 접힘/페이드 애니메이션과 창 제거가
    /// 전부 이 값에서 파생되어 표면마다 어긋나지 않는다.
    static let closeDuration: TimeInterval = 0.18
    static let closeAnimation: Animation = .smooth(duration: closeDuration)

    static let columnWidth: CGFloat = 160
    /// 다운로드 칸 폭. 12pt 파일명이 20자 안팎까지 보인다 (Focus를 줄여 생긴 폭을 여기 쓴다).
    static let downloadsColumnWidth: CGFloat = 200
    /// Focus 칸 폭. 104pt 다이얼이 들어간다.
    static let focusColumnWidth: CGFloat = 116
    /// Apps 탭 아이콘 격자 폭. 앱 수에 따라 2열(4개까지) 또는 3열이다.
    static func appGridColumnWidth(appCount: Int) -> CGFloat {
        let columns = CGFloat(LauncherListPolicy.appIconColumns(forCount: appCount))
        return columns * NotchAppIconTile.tileSize + (columns - 1) * NotchAppIconTile.columnGap
            + 4
    }

    /// To-do 칸 폭. 도커를 열 때(이 뷰가 만들어질 때) 저장된 항목으로 한 번 정하고, 열려 있는 동안은
    /// 바꾸지 않는다. 가운데 정렬 도커라 폭이 바뀌면 다른 칸이 마우스 아래에서 비켜나기 때문이다.
    /// 앱을 켜고 처음 열 때 항목을 아직 못 읽었으면, 읽는 즉시 한 번만 맞춘다.
    @State private var todoWidth: CGFloat? = NotchTodoView.knownTitles.map(
        NotchTodoView.columnWidth(titles:))

    /// 읽어 보니 비어 있는 선반. 비면 칸이 제목 폭(+ 접기 버튼)으로 좁아진다.
    @State private var emptyShelves: Set<NotchWidget> = []

    /// 빈 선반 칸 폭: 제목 + 폴더 화살표(14) + 접기 버튼(22)과 한 줄 안내 중 넓은 쪽.
    private static func emptyShelfWidth(title: String, message: String) -> CGFloat {
        let header = NotchTextMetrics.headerWidth(title: title) + 14 + 22
        let line = NotchTextMetrics.metaWidth(message) + 12
        return CGFloat(
            LauncherListPolicy.listColumnWidth(contentWidth: Double(max(header, line))))
    }

    private func setShelfEmpty(_ widget: NotchWidget, _ empty: Bool) {
        guard emptyShelves.contains(widget) != empty else { return }
        withAnimation(.smooth(duration: 0.22)) {
            if empty { emptyShelves.insert(widget) } else { emptyShelves.remove(widget) }
        }
    }

    /// 목록의 가장 긴 줄(이름 + 키캡) 폭.
    private static func launcherRowsWidth(_ section: LauncherListSection) -> CGFloat {
        section.entries.map { entry in
            NotchTextMetrics.rowWidth(
                name: entry.site.name, keycap: LauncherListPolicy.shortcutBadge(for: entry.site))
        }.max() ?? 0
    }

    /// 칸마다 내용에 맞는 폭. 목록 칸은 가장 긴 줄(이름 + 키캡)과 제목 중 긴 쪽에 맞춘다.
    private func width(for slot: NotchSlotContent) -> CGFloat {
        switch slot {
        case .downloads where emptyShelves.contains(.downloads):
            return Self.emptyShelfWidth(title: "Downloads", message: "No downloads yet")
        case .screenshots where emptyShelves.contains(.screenshots):
            // 비어서 저절로 접혔다가 사용자가 띠 아이콘으로 펼친 경우.
            return Self.emptyShelfWidth(title: "Screenshots", message: "No screenshots yet")
        case .launcherTabs(let sections):
            return CGFloat(
                LauncherListPolicy.launcherTabsColumnWidth(
                    titleWidth: NotchTabHeader.widestTitleWidth(
                        sections.map { Self.sectionTitle($0.launchType) }),
                    contentWidth: Double(sections.map(Self.launcherRowsWidth).max() ?? 0),
                    tabCount: sections.count))
        case .apps(let apps, _):
            let tabs = AppsSlotTab.available(hasApps: apps != nil)
            return CGFloat(
                LauncherListPolicy.launcherTabsColumnWidth(
                    titleWidth: NotchTabHeader.widestTitleWidth(tabs.map(\.title)),
                    contentWidth: Double(
                        max(
                            Self.appGridColumnWidth(appCount: apps?.entries.count ?? 0),
                            NotchLayoutsView.columnWidth)),
                    tabCount: tabs.count))
        case .awake:
            return Self.focusColumnWidth
        case .todo:
            return todoWidth ?? NotchTodoView.columnWidth(titles: [])
        case .downloads:
            // 파일명이 핵심이라 목록 칸보다 넓게 쓴다 (아이콘 20 + 이름 + 짧은 시각).
            return Self.downloadsColumnWidth
        case .screenshots:
            // 썸네일 34 + 간격 6 + 시각 문구 + Spacer 앞 간격 6 + 좌우 여백 12.
            let label =
                ["88 min ago", "Yesterday", "88 hr ago"]
                .map(NotchTextMetrics.metaWidth).max() ?? 0
            // 제목 + 폴더 화살표(14) + 접기 버튼(18)과 그 앞 간격(4).
            let header = NotchTextMetrics.headerWidth(title: "Screenshots") + 14 + 22
            return CGFloat(
                LauncherListPolicy.listColumnWidth(
                    contentWidth: Double(max(34 + 6 + label + 6 + 12 + 8, header))))
        }
    }
    /// 그림자가 창 경계에서 잘리지 않도록 검정 형태 주변에 두는 투명 여백.
    /// 그림자 확산(radius 9, y 4)이 이 여백 안에서 완전히 소멸해야
    /// 창 가장자리에 그림자 경계선이 생기지 않는다.
    static let shadowPadding: CGFloat = NotchGeometry.shadowPadding
    /// 패널 실루엣. 상단 모서리는 바깥으로 흐르는 오목 곡선이라
    /// 노치 도크가 상단바에서 빠져나온 것처럼 라인이 이어진다.
    private var panelShape: AnyShape {
        AnyShape(
            NotchDockShape(
                topCornerRadius: NotchGeometry.dockFlareRadius,
                bottomCornerRadius: NotchGeometry.dockBottomRadius))
    }

    /// 림 스트로크용 실루엣. 상단 변이 열려 있어 노치 경계에 흰 줄이 생기지 않는다.
    private var rimShape: AnyShape {
        AnyShape(
            NotchDockShape(
                topCornerRadius: NotchGeometry.dockFlareRadius,
                bottomCornerRadius: NotchGeometry.dockBottomRadius, isRim: true))
    }

    private var hasNativeLiquidGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    private var usesSemanticGlass: Bool {
        style == .glass && hasNativeLiquidGlass
    }

    /// 스타일별 채움. Custom은 사용자가 고른 색·불투명도 페이드.
    /// Glass는 macOS 26+에서 투명 기반, 그 이하는 검정 Custom 폴백이다.
    private var panelFill: AnyShapeStyle {
        switch style {
        case .custom:
            return AnyShapeStyle(
                NotchDockStyle.fade(
                    NotchDockStyle.color(fromHex: reveal.colorHex),
                    bottomOpacity: reveal.bottomOpacity))
        case .glass:
            if hasNativeLiquidGlass { return AnyShapeStyle(Color.clear) }
            return AnyShapeStyle(
                NotchDockStyle.fade(.black, bottomOpacity: reveal.bottomOpacity))
        }
    }

    var body: some View {
        contentBody
            .background(
                // 상단바 구간은 노치 연장(검정), 그 아래 콘텐츠 박스만 커스텀 색.
                // 검정 띠는 노치가 배경을 누른 듯한 곡선 경계로 내려온다.
                ZStack(alignment: .top) {
                    panelShape.fill(panelFill)
                    // 모든 스타일: 좌우 오목 코너 bridge를 본체와 같은 재질로 채워, 패널 색이
                    // 화면 상단 꼭짓점까지 닿고 배경화면 틈이 생기지 않게 한다.
                    if usesSemanticGlass {
                        NotchDockStyle.liquidGlassLayer(
                            shape: panelShape, material: glassMaterial)
                        NotchDockStyle.liquidGlassLayer(
                            shape: GlassCornerBridgeShape(
                                radius: NotchGeometry.dockFlareRadius),
                            material: glassMaterial)
                    } else {
                        GlassCornerBridgeShape(radius: NotchGeometry.dockFlareRadius)
                            .fill(panelFill)
                    }
                    // 검정 띠는 기존 도커 외곽 안에만 남아 bridge 위의 상단
                    // 실루엣을 보존한다.
                    PressedStripShape(
                        plateauHalfWidth: stripPlateauHalfWidth,
                        centerDepth: topInset,
                        // 모든 스타일에서 검정은 외곽 코너에서 0까지 사라져, 패널 색(bridge)이
                        // 화면 상단 좌우 꼭짓점에 직접 닿는다.
                        edgeDepth: 0
                    )
                    .fill(Color.black)
                    .clipShape(panelShape)
                }
                // 어두운 배경에서 형태가 묻히지 않도록 잡아주는 미세한 림 하이라이트.
                // 상단 변이 열린 rim 형태라 노치 경계에는 줄이 없다.
                .overlay(rimShape.stroke(Color.white.opacity(0.08), lineWidth: 1))
                // 은은하게 띄우는 정도만. 강한 그림자는 상단바 주변에서 부자연스럽다.
                .shadow(color: .black.opacity(0.22), radius: 9, y: 4)
            )
            // 상단 띠 왼쪽: Focus 칸이 보이면 비움, 아니면 Focus 켜짐 → 남은 시간, 꺼짐 → 마스코트.
            .overlay(alignment: .top) { leftStripContent }
            // 상단 띠 오른쪽: Drop 상자(파일이 없어도 펼친 동안은 빈 상자), 그 오른쪽 Mirror, Quick Note.
            // 파일이 있으면 상자는 별도 배지 창이 그리고, 없으면 여기서 숫자 없이 그린다.
            .overlay(alignment: .top) {
                NotchStripTools(
                    notchRightEdge: stripPlateauHalfWidth
                        - NotchGeometry.stripPlateauSideWidth,
                    stripHeight: topInset,
                    besideDropBadge: true,
                    showsEmptyDropBox: dropFiles.isEmpty,
                    showsMirror: showsMirror,
                    showsNote: showsNote,
                    showsCoverScreens: showsCoverScreens)
            }
            .overlay(alignment: .topLeading) {
                if showsShoulderGuides { shoulderGuides }
            }
            // 파일 드래그 중에는 도커 전체를 덮는 반투명 Drop here 레이어.
            .overlay { dropOverlay }
            // 상단은 화면 모서리에 밀착해야 하므로 좌우·하단에만 그림자 여백을 둔다.
            .padding(.horizontal, Self.shadowPadding)
            .padding(.bottom, Self.shadowPadding)
            // 창 크기에 눌리지 않은 본래 크기로 배치한다. 창보다 크면 창이 이 크기를 따라온다.
            // (눌리면 Drop 줄·구분선이 위젯 줄과 겹치고, 잰 크기도 창 크기라 창이 커지지 않는다.)
            .fixedSize()
            // 스케일 애니메이션 전의 실제 크기를 잰다 (scaleEffect는 레이아웃 크기를 바꾸지 않는다).
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: NotchContentSizeKey.self, value: geo.size)
                }
            )
            .onPreferenceChange(NotchContentSizeKey.self) { size in
                onContentSizeChange(size)
            }
            // Keep Awake를 Focus 위젯·상태 메뉴에서 켜고 끄면 상단 띠 시계를 바로 바꾼다.
            .onReceive(
                NotificationCenter.default.publisher(for: KeepAwakeController.didChangeNotification)
            ) { note in
                liveAwakeSessionEnd = .some(note.object as? Date)
            }
            // 노치에서 아래로 펼쳐지는 등장. 페이드 대신 상단 고정 확장을 쓴다.
            .scaleEffect(x: 1, y: reveal.revealed ? 1 : 0.4, anchor: .top)
            .opacity(reveal.revealed ? 1 : 0)
            // 창이 콘텐츠보다 커져도(픽셀 정렬 등) 여분은 항상 아래로 가고,
            // 형태 상단은 창 상단 = 화면 최상단에 밀착한다.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 검정 띠 왼쪽: 접힌 선반 아이콘(노치 쪽부터)과 물범(그 바깥쪽). 물범은 늘 여기 있고,
    /// Focus가 켜져 있으면 깨어 꼬리를 흔든다(Focus 칸은 다이얼과 남은 시간을 보여 준다).
    @ViewBuilder private var leftStripContent: some View {
        let collapsed = collapsedStripWidgets
        let leading = NotchLauncherPolicy.stripLeading()
        let notchHalf = stripPlateauHalfWidth - NotchGeometry.stripPlateauSideWidth
        GeometryReader { geo in
            let notchLeft = geo.size.width / 2 - notchHalf
            let offsets = NotchLauncherPolicy.leftStripIconCenterOffsets(count: collapsed.count)
            ZStack(alignment: .topLeading) {
                ForEach(Array(collapsed.enumerated()), id: \.element) { index, widget in
                    NotchStripShelfIcon(
                        symbol: Self.shoulderSymbol(widget), title: Self.shoulderTitle(widget),
                        height: topInset
                    ) {
                        expandFromStrip(widget)
                    }
                    // 왼쪽에서 오른쪽으로 칸 순서가 읽히도록 마지막 칸이 노치에 가장 가깝다.
                    .position(
                        x: notchLeft - offsets[collapsed.count - 1 - index], y: topInset / 2)
                }
                if leading == .mascot {
                    // Focus가 켜져 있으면 깨어 꼬리를 흔들고(30분 미만이면 졸림), 꺼져 있으면 쉰다.
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let remaining = currentAwakeSessionEnd.map {
                            $0.timeIntervalSince(context.date)
                        }
                        let mood = ChapMascot.focusMood(remaining: remaining)
                        NotchMascotView(
                            mood: mood == .asleep ? .awake : mood,
                            isAnimating: reveal.revealed,
                            wagsContinuously: mood != .asleep,
                            isFocusing: mood != .asleep)
                    }
                    .position(
                        x: notchLeft
                            - NotchLauncherPolicy.stripMascotCenterOffset(
                                collapsedIconCount: collapsed.count),
                        y: topInset / 2
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }

    /// 접혀서 띠 왼쪽에 아이콘으로 놓이는 선반. 칸 순서대로 (왼쪽 → 오른쪽).
    private var collapsedStripWidgets: [NotchWidget] {
        let collapsed = effectiveCollapsed
        return slots.compactMap(\.collapsibleWidget).filter { collapsed.contains($0) }
    }

    @State private var dropTargeted = false

    /// 파일 드래그 중 도커를 덮는 반투명 드롭 레이어. 드래그가 노치에
    /// 닿으면(컨트롤러 플래그) 나타나고, 레이어 위에 드는 동안 유지되며,
    /// 드롭하면 보관함에 저장하고 사라진다.
    @ViewBuilder private var dropOverlay: some View {
        let visible = reveal.isDropTargetActive || dropTargeted
        ZStack {
            panelShape.fill(Color.black.opacity(0.55))
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 24))
                    .foregroundColor(dropTargeted ? DS.accent : DS.accentLight)
                Text("Drop here")
                    .font(DS.headlineFont)
                    .foregroundColor(.white.opacity(0.95))
            }
            .padding(.top, topInset)
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: visible)
        .allowsHitTesting(visible)
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            reveal.isDropTargetActive = false
            dropTargeted = false
            ChapDrop.storeAsync(urls) { _, failedCount in
                if failedCount > 0 {
                    LauncherUtils.showAlert(
                        message: "Some files could not be added",
                        info: "\(failedCount) item(s) could not be added to Chap Drop.")
                }
            }
            return true
        } isTargeted: {
            dropTargeted = $0
        }
    }

    @State private var dropFiles: [URL] = ChapDrop.previewOverride ?? []
    @State private var isRefreshingDropFiles = false
    @State private var dropRefreshPending = false

    /// 전경 대비 계산용 배경색. Glass는 색을 깔지 않으므로 어두운 재질로
    /// 취급해 검정 기준 전경값을 그대로 쓴다.
    private var contrastBackgroundHex: String {
        usesSemanticGlass ? Config.notchPanelColorHexDefault : reveal.colorHex
    }

    private var usesDarkCustomForeground: Bool {
        !usesSemanticGlass
            && NotchContrastPolicy.usesDarkForeground(
                backgroundHex: style == .glass
                    ? Config.notchPanelColorHexDefault : reveal.colorHex)
    }

    /// Glass에서는 시스템 semantic 색이 재질의 vibrancy와 배경에 맞춰
    /// 자동 적응한다. 비-Glass는 기존 고대비 흰색 체계를 유지한다.
    private var primaryForeground: Color {
        // Apple 기본 계층: 콘텐츠 이름은 semantic primary 그대로 사용한다.
        // 시스템이 Liquid Glass와 활성 appearance에 맞춰 색·vibrancy를 결정한다.
        if usesSemanticGlass { return .primary }
        return usesDarkCustomForeground ? .black.opacity(0.87) : .white.opacity(0.96)
    }

    private var secondaryForeground: Color {
        if usesSemanticGlass { return .secondary }
        return usesDarkCustomForeground
            ? .black.opacity(0.65)
            : .white.opacity(
                NotchContrastPolicy.secondaryTextOpacity(
                    backgroundHex: contrastBackgroundHex))
    }

    private var accentForeground: Color {
        // Glass에서도 기능 구분 아이콘은 Chap 액센트 블루를 유지한다.
        // 의미는 옆 텍스트가 중복 전달하므로 색만으로 정보를 구분하지 않는다.
        if usesSemanticGlass { return DS.accent }
        if NotchContrastPolicy.usesAccentForeground(backgroundHex: contrastBackgroundHex) {
            return DS.accent
        }
        return usesDarkCustomForeground ? .black.opacity(0.87) : .white.opacity(0.95)
    }

    /// Glass 재질 위에는 시스템 vibrancy가 대비를 담당하므로 검정 그림자를
    /// 넣지 않는다. 비-Glass에서만 기존 윤곽 보정을 유지한다.
    private var textShadowOpacity: Double {
        usesSemanticGlass || usesDarkCustomForeground ? 0 : 0.75
    }

    /// Apple식 hover: Glass에서는 semantic primary의 8% 회색 면이
    /// appearance에 맞춰 적응하고, 다른 스타일은 기존 흰색 면을 유지한다.
    private var rowHoverBackground: Color {
        if usesSemanticGlass { return Color.primary.opacity(0.08) }
        return usesDarkCustomForeground ? .black.opacity(0.08) : .white.opacity(0.16)
    }

    /// 섹션 제목·아이콘: 본문색 62%. 기본 보조 회색보다 밝은 Glass 위에서 또렷하다.
    /// Custom은 배경 대비 정책의 보조 불투명도를 그대로 쓴다.
    private var headingForeground: Color {
        usesSemanticGlass ? Color.primary.opacity(0.62) : secondaryForeground
    }

    /// 제목 아이콘: 연한 대표 블루. 어두운 바탕(Glass 다크·검정 Custom)은 밝은 블루를 쓴다.
    private var iconForeground: Color {
        let dark = usesSemanticGlass ? colorScheme == .dark : !usesDarkCustomForeground
        return DS.notchIconColor(onDarkBackground: dark)
    }

    /// 키캡 글자: 본문색 80%. 옅은 회색보다 대비가 높아 3:1 이상을 지킨다.
    private var keycapForeground: Color { primaryForeground.opacity(0.8) }

    /// 키캡 바탕: 본문색 14%. 구분선용 `subtleSurface`(10%)보다 한 단계 진하다.
    private var keycapBackground: Color { primaryForeground.opacity(0.14) }

    private var subtleSurface: Color {
        if usesSemanticGlass { return Color.primary.opacity(0.10) }
        return usesDarkCustomForeground ? .black.opacity(0.10) : .white.opacity(0.10)
    }

    /// 섹션 콘텐츠 본문. 하단에 Chap Drop 파일 행이 조건부로 붙는다.
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DS.spacingSmall) {
            // 위젯 칸을 좌우로 나란히 배치해 패널이 아래가 아니라 옆으로 길어진다.
            // 칸 사이에는 구분선 없이 넓은 간격만 둔다. 칸 제목(아이콘 + 이름)이 그룹 경계 역할을 한다.
            HStack(alignment: .top, spacing: DS.notchColumnGap) {
                ForEach(Array(visibleSlots.enumerated()), id: \.offset) { _, slot in
                    slotView(slot)
                        .frame(width: width(for: slot), alignment: .leading)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            // 칸 높이를 가장 긴 칸의 이상 높이로 고정해 무한 확장을 막는다.
            .fixedSize(horizontal: false, vertical: true)
            // 도커가 최소 폭보다 좁은 내용을 담으면 위젯 줄을 가운데에 둔다.
            .frame(maxWidth: .infinity, alignment: .center)

            // Chap Drop 파일 행. 파일이 없으면 섹션 자체가 사라져
            // 도커는 원래 크기로 돌아간다.
            if !dropFiles.isEmpty {
                Rectangle()
                    .fill(subtleSurface)
                    .frame(height: 1)
                    .padding(.top, 2)
                // 파일은 아이콘 + 한 줄 파일명으로 둔다. 전체 이름은 툴팁과 VoiceOver로 제공한다.
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(DS.notchLabel)
                        .foregroundColor(headingForeground)
                        .padding(.horizontal, 6)
                        .accessibilityHidden(true)
                    ForEach(dropFiles, id: \.self) { url in
                        NotchDropFileItem(
                            url: url,
                            primaryForeground: primaryForeground,
                            textShadowOpacity: textShadowOpacity,
                            hoverBackground: rowHoverBackground
                        ) {
                            ChapDrop.removeAsync(url) { removed in
                                if !removed {
                                    LauncherUtils.showAlert(
                                        message: "File could not be removed",
                                        info:
                                            "Chap could not remove \(url.lastPathComponent) from Drop."
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.padding)
        .padding(.top, topInset + NotchGeometry.contentTopGap)
        .padding(.bottom, DS.paddingSmall)
        // 칸을 접으면 도커는 남은 칸에 맞춰 줄어든다. 최소 폭이 검정 띠(노치 + 좌우 상태 영역 + 곡선)를
        // 늘 감싸므로 띠 아이콘·물범은 노치 기준 제자리를 지킨다.
        .frame(minWidth: minWidth)
        .onAppear {
            refreshDropFiles()
            checkScreenshots()
        }
        .onReceive(screenshotCheckTimer) { _ in checkScreenshots() }
        .onReceive(
            NotificationCenter.default.publisher(for: ChapDrop.didChangeNotification)
        ) { _ in
            refreshDropFiles()
        }
    }

    private func refreshDropFiles() {
        guard !isRefreshingDropFiles else {
            dropRefreshPending = true
            return
        }
        isRefreshingDropFiles = true
        ChapDrop.recentFilesAsync(limit: DropPolicy.maxDockItems) { files in
            dropFiles = files
            isRefreshingDropFiles = false
            if dropRefreshPending {
                dropRefreshPending = false
                refreshDropFiles()
            }
        }
    }

    /// 스크린샷이 하나도 없어 저절로 접힌 Screenshots 칸. 저장하지 않는다. 스크린샷이 생기면 펼쳐지고,
    /// 띠 아이콘을 누르면 이번에 열린 동안만 펼쳐 둔다(`autoCollapseDismissed`).
    @State private var screenshotsAutoCollapsed = ScreenshotShelf.initiallyEmpty
    @State private var autoCollapseDismissed = false
    private let screenshotCheckTimer = Timer.publish(every: 2, on: .main, in: .common)
        .autoconnect()

    /// 사용자가 접은 칸 + 비어서 저절로 접힌 칸.
    private var effectiveCollapsed: [NotchWidget] {
        var list = reveal.collapsedWidgets
        if screenshotsAutoCollapsed, !autoCollapseDismissed, !list.contains(.screenshots) {
            list.append(.screenshots)
        }
        return list
    }

    /// Screenshots 칸이 배치돼 있으면 스크린샷 유무를 확인한다(칸이 접혀 있어도).
    private func checkScreenshots() {
        guard slots.contains(where: { $0.collapsibleWidget == .screenshots }) else { return }
        let apply: ([URL]) -> Void = { shots in
            let empty = ShelfAutoCollapsePolicy.collapsesScreenshots(count: shots.count)
            ScreenshotShelf.lastKnownEmpty = empty
            guard empty != screenshotsAutoCollapsed else { return }
            if !empty {
                // 펼쳐질 때는 창을 먼저 넓힌다.
                if let slot = slots.first(where: { $0.collapsibleWidget == .screenshots }),
                    !reveal.collapsedWidgets.contains(.screenshots), !autoCollapseDismissed
                {
                    onPrepareExpand(width(for: slot) + DS.notchColumnGap)
                }
            }
            DispatchQueue.main.async {
                withAnimation(.smooth(duration: 0.22)) { screenshotsAutoCollapsed = empty }
            }
        }
        if let preview = ScreenshotShelf.previewOverride {
            screenshotsAutoCollapsed = ShelfAutoCollapsePolicy.collapsesScreenshots(
                count: preview.count)
            return
        }
        ScreenshotShelf.recentScreenshotsAsync(completion: apply)
    }

    /// 접힌 칸 아이콘을 눌렀을 때: 사용자가 접은 칸이면 펼쳐 저장하고, 비어서 접힌 칸이면 이번에만 펼친다.
    private func expandFromStrip(_ widget: NotchWidget) {
        if reveal.collapsedWidgets.contains(widget) {
            setCollapsed(widget, false)
            return
        }
        guard let slot = slots.first(where: { $0.collapsibleWidget == widget }) else { return }
        onPrepareExpand(width(for: slot) + DS.notchColumnGap)
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.22)) { autoCollapseDismissed = true }
        }
    }

    /// 접힌 칸을 뺀, 위젯 줄에 실제로 그릴 칸들.
    private var visibleSlots: [NotchSlotContent] {
        let collapsed = effectiveCollapsed
        return slots.filter { slot in
            guard let widget = slot.collapsibleWidget else { return true }
            return !collapsed.contains(widget)
        }
    }

    private func setCollapsed(_ widget: NotchWidget, _ collapsed: Bool) {
        var list = reveal.collapsedWidgets.filter { $0 != widget }
        if collapsed { list.append(widget) }
        list = NotchShoulderPolicy.normalized(list)
        let apply = {
            withAnimation(.smooth(duration: 0.22)) { reveal.collapsedWidgets = list }
            onCollapsedChange(list)
        }
        // 펼칠 때는 창을 먼저 넓히고 다음 틱에 칸을 펼친다. 같은 틱에 바꾸면 넓어진 내용이 아직 좁은
        // 창에 잘려 도커가 접혔다 펼쳐지는 것처럼 끊겨 보인다. 접을 때는 창을 나중에 줄인다(`resizeSteps`).
        if !collapsed, let slot = slots.first(where: { $0.collapsibleWidget == widget }) {
            onPrepareExpand(width(for: slot) + DS.notchColumnGap)
            DispatchQueue.main.async(execute: apply)
        } else {
            apply()
        }
    }

    /// (개발용) 어깨 경계선. 빨강 = 어깨(아이콘 자리), 주황 = 검정 띠 곡선 구간, 파랑 = 노치 plateau.
    private var shoulderGuides: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let flare = NotchGeometry.dockFlareRadius
            let plateauLeft = w / 2 - stripPlateauHalfWidth
            let curveLeft = plateauLeft - NotchGeometry.stripFalloff
            let iconStart = flare + 8
            ZStack(alignment: .topLeading) {
                ForEach([false, true], id: \.self) { mirrored in
                    let place: (CGFloat, CGFloat) -> CGFloat = { x, width in
                        mirrored ? w - x - width : x
                    }
                    guide(.red, width: curveLeft - flare, height: topInset)
                        .offset(x: place(flare, curveLeft - flare))
                    guide(.orange, width: NotchGeometry.stripFalloff, height: topInset)
                        .offset(x: place(curveLeft, NotchGeometry.stripFalloff))
                    Rectangle().fill(Color.red.opacity(0.5)).frame(width: 1, height: topInset)
                        .offset(x: mirrored ? w - iconStart : iconStart)
                    Text("\(Int(curveLeft - flare))pt")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.red)
                        .offset(x: place(flare + 4, 34), y: topInset + 2)
                }
                guide(.blue, width: 2 * stripPlateauHalfWidth, height: topInset)
                    .offset(x: plateauLeft)
            }
        }
        .allowsHitTesting(false)
    }

    private func guide(_ color: Color, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(color.opacity(0.10))
            .overlay(Rectangle().stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .frame(width: max(width, 0), height: height)
    }

    static func shoulderSymbol(_ widget: NotchWidget) -> String {
        widget == .screenshots ? "camera.viewfinder" : "arrow.down.circle"
    }

    static func shoulderTitle(_ widget: NotchWidget) -> String {
        widget == .screenshots ? "Screenshots" : "Downloads"
    }

    @ViewBuilder
    private func slotView(_ slot: NotchSlotContent) -> some View {
        switch slot {
        case .launcherTabs(let sections):
            NotchLaunchersTabSlot(
                sections: sections, palette: widgetPalette, onOpenSettings: onOpenSettings
            ) { section in
                launcherBody(section)
            }
        case .screenshots:
            NotchScreenshotShelfView(
                backgroundHex: contrastBackgroundHex,
                usesSemanticForeground: usesSemanticGlass,
                onCollapse: { setCollapsed(.screenshots, true) },
                onEmptyChange: { setShelfEmpty(.screenshots, $0) })
        case .downloads:
            NotchDownloadsShelfView(
                backgroundHex: contrastBackgroundHex,
                usesSemanticForeground: usesSemanticGlass,
                onCollapse: { setCollapsed(.downloads, true) },
                onEmptyChange: { setShelfEmpty(.downloads, $0) })
        case .awake:
            NotchFocusView(
                palette: widgetPalette, sessionEnd: currentAwakeSessionEnd,
                timerEnd: timerEndProvider())
        case .todo:
            NotchTodoView(palette: widgetPalette) { titles in
                // 처음 읽었을 때만 맞춘다. 그 뒤의 추가·수정·삭제는 다음에 열 때 반영된다.
                if todoWidth == nil { todoWidth = NotchTodoView.columnWidth(titles: titles) }
            }
        case .apps(let apps, let layouts):
            NotchAppsSlot(
                hasApps: apps != nil, palette: widgetPalette,
                onOpenAppSettings: { onOpenSettings(.app) },
                onOpenLayoutSettings: onOpenLayoutSettings,
                apps: {
                    if let apps { appIconGrid(apps) }
                },
                layouts: {
                    NotchLayoutsView(
                        layouts: layouts, busyID: busyLayoutIDProvider(),
                        palette: widgetPalette,
                        onOpen: onOpenLayout, onCapture: onCaptureLayout,
                        onEdit: onEditLayout, onRemove: onRemoveLayout)
                })
        }
    }

    private var widgetPalette: NotchWidgetPalette {
        NotchWidgetPalette(
            primary: primaryForeground,
            secondary: secondaryForeground,
            accent: accentForeground,
            heading: headingForeground,
            textShadowOpacity: textShadowOpacity,
            hoverBackground: rowHoverBackground,
            subtleSurface: subtleSurface,
            icon: iconForeground)
    }

    /// Launchers 칸 본문: Sites·Finder 목록.
    private func launcherBody(_ section: LauncherListSection) -> some View {
        launcherRows(section)
    }

    /// Apps 칸 Apps 탭: 앱 아이콘 격자(4개까지 2열, 5~6개 3열, 최대 2줄). 단축키가 있으면 아이콘 모서리에 배지를 붙인다.
    private func appIconGrid(_ section: LauncherListSection) -> some View {
        // 고정 폭 열: flexible 열은 칸 폭(160pt)을 나눠 가져 아이콘 사이가 벌어진다.
        LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .fixed(NotchAppIconTile.tileSize), spacing: NotchAppIconTile.columnGap),
                count: LauncherListPolicy.appIconColumns(
                    forCount: min(
                        section.entries.count,
                        LauncherListPolicy.maxEntriesPerNotchSlot(for: section.launchType)))),
            alignment: .center, spacing: NotchAppIconTile.rowGap
        ) {
            ForEach(
                section.entries.prefix(
                    LauncherListPolicy.maxEntriesPerNotchSlot(for: section.launchType)),
                id: \.siteIndex
            ) { entry in
                NotchAppIconTile(
                    entry: entry,
                    isOptionHeld: reveal.isOptionHeld,
                    primaryForeground: primaryForeground,
                    badgeForeground: keycapForeground,
                    badgeBackground: keycapBackground,
                    hoverBackground: rowHoverBackground
                ) {
                    onLaunch(entry.siteIndex)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        // 배지 글자는 ⌥와 함께 누르는 키다. 수식키 안내는 툴팁으로만 둔다.
        // 칸 폭 안에서 가운데. 높이는 Apps 칸(`NotchAppsSlot`)이 목록 칸 4줄 높이로 맞춘다.
        .frame(maxWidth: .infinity)
    }

    private func launcherRows(_ section: LauncherListSection) -> some View {
        VStack(alignment: .leading, spacing: NotchAppIconTile.listRowSpacing) {
            ForEach(
                section.entries.prefix(
                    LauncherListPolicy.maxEntriesPerNotchSlot(for: section.launchType)),
                id: \.siteIndex
            ) { entry in
                NotchLauncherRow(
                    entry: entry,
                    isOptionHeld: reveal.isOptionHeld,
                    primaryForeground: primaryForeground,
                    shortcutForeground: keycapForeground,
                    textShadowOpacity: textShadowOpacity,
                    hoverBackground: rowHoverBackground,
                    keycapBackground: keycapBackground
                ) {
                    onLaunch(entry.siteIndex)
                }
            }
        }
    }

    private static func sectionTitle(_ launchType: LaunchType) -> String {
        LauncherListPolicy.title(for: launchType)
    }
}
