import SwiftUI

/// 노치 패널 한 칸의 렌더링 내용.
enum NotchSlotContent {
    /// 런처 목록 위젯.
    case launchers(LauncherListSection)
    /// 스크린샷 선반 위젯. 파일 목록은 뷰가 background queue에서 읽는다.
    case screenshots
    /// 다운로드 선반 위젯.
    case downloads
    /// Focus(Keep Mac Awake) 위젯.
    case awake

    /// config의 위젯 배치를 실제로 그릴 칸으로 바꾼다. 빈 칸과 항목이 없는 런처 칸은 뺀다.
    /// 노치 패널과 오프스크린 렌더 도구가 같은 규칙을 쓴다.
    static func slots(widgets: [NotchWidget], sites: [Site]) -> [NotchSlotContent] {
        // 위젯 배치는 사용자가 명시적으로 고른 것이므로 메뉴의 숨김 설정과 무관하다.
        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])
        return widgets.compactMap { widget -> NotchSlotContent? in
            switch widget {
            case .none, .drop:
                // Drop 파일은 메인 도커 하단 행이 전담한다.
                return nil
            case .screenshots: return .screenshots
            case .downloads: return .downloads
            case .awake: return .awake
            case .sites, .apps, .folders:
                return sections.first { $0.launchType == widget.launchType }
                    .map(NotchSlotContent.launchers)
            }
        }
    }
}

/// 패널 펼침/접힘 상태와 실시간 조절 값. 컨트롤러가 접힘 애니메이션과
/// 불투명도 프리뷰를 구동할 수 있도록 뷰 외부에서 관찰 가능한 모델로 둔다.
final class NotchRevealModel: ObservableObject {
    @Published var revealed = false
    @Published var bottomOpacity: Double = Config.notchPanelOpacityDefault
    @Published var colorHex: String = Config.notchPanelColorHexDefault
    /// 파일 드래그가 노치에 닿아 "Drop here" 레이어를 덮어야 하는 상태.
    @Published var isDropTargetActive = false
    /// ⌥를 누르고 있는 동안. 키캡이 강조되고 "⌥1"처럼 수식키를 함께 보여준다.
    @Published var isOptionHeld = false
    /// 메모 모드: 위젯 줄 자리를 넓은 Quick Note 편집기로 바꾼다. 도커를 열 때마다 꺼진 채 시작한다.
    @Published var isNoteMode = false
}

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
    let awakeSessionEnd: Date?
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
    let onLaunch: (Int) -> Void
    /// 실제 레이아웃이 끝난 도커 크기(그림자 여백 포함). 메모 모드처럼 내용이 바뀌면
    /// 컨트롤러가 이 값으로 창을 다시 맞춘다. 타이밍 추측 없이 SwiftUI가 잰 값을 쓴다.
    var onContentSizeChange: (CGSize) -> Void = { _ in }
    /// 런처 칸 제목을 누르면 그 타입이 선택된 설정창을 연다.
    var onOpenSettings: (LaunchType) -> Void = { _ in }
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
    /// 다운로드 칸 폭. 파일명이 20자 안팎까지 보인다.
    static let downloadsColumnWidth: CGFloat = 200
    /// Focus 칸 폭. 시간 버튼 셋(1h·4h·8h)이 한 줄에 들어간다.
    static let focusColumnWidth: CGFloat = 150
    /// 메모 모드의 위젯 줄 높이. 도구 줄을 빼면 13pt 본문이 약 11줄 보인다.
    static let noteModeHeight: CGFloat = 200

    /// Apps 칸 폭: 2열 아이콘 격자 폭.
    static var appGridColumnWidth: CGFloat {
        let columns = CGFloat(LauncherListPolicy.appIconColumns)
        return columns * NotchAppIconTile.tileSize + (columns - 1) * NotchAppIconTile.columnGap
            + 4
    }

    /// 칸마다 내용에 맞는 폭. 목록 칸은 가장 긴 줄(이름 + 키캡)과 제목 중 긴 쪽에 맞춘다.
    private func width(for slot: NotchSlotContent) -> CGFloat {
        switch slot {
        case .launchers(let section) where section.launchType == .app:
            return max(Self.appGridColumnWidth, NotchTextMetrics.headerWidth(title: "Apps"))
        case .launchers(let section):
            let rows = section.entries.map { entry -> CGFloat in
                let key = LauncherListPolicy.shortcutBadge(for: entry.site)
                return NotchTextMetrics.rowWidth(name: entry.site.name, keycap: key)
            }
            let header = NotchTextMetrics.headerWidth(title: Self.sectionTitle(section.launchType))
            return CGFloat(
                LauncherListPolicy.listColumnWidth(
                    contentWidth: Double(max(rows.max() ?? 0, header))))
        case .awake:
            return Self.focusColumnWidth
        case .downloads:
            // 파일명이 핵심이라 목록 칸보다 넓게 쓴다 (아이콘 20 + 이름 + 짧은 시각).
            return Self.downloadsColumnWidth
        case .screenshots:
            // 썸네일 34 + 간격 6 + 시각 문구 + Spacer 앞 간격 6 + 좌우 여백 12.
            let label =
                ["88 min ago", "Yesterday", "88 hr ago"]
                .map(NotchTextMetrics.metaWidth).max() ?? 0
            let header = NotchTextMetrics.headerWidth(title: "Screenshots") + 14
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
                    // Glass 스타일: 본체 재질과 좌우 오목 코너 bridge를 함께 그린다.
                    // bridge가 검정 상단선의 화면 꼭짓점까지 닿아 배경화면 틈을 없앤다.
                    if usesSemanticGlass {
                        NotchDockStyle.liquidGlassLayer(
                            shape: panelShape, material: glassMaterial)
                        NotchDockStyle.liquidGlassLayer(
                            shape: GlassCornerBridgeShape(
                                radius: NotchGeometry.dockFlareRadius),
                            material: glassMaterial)
                    }
                    // 검정 띠는 기존 도커 외곽 안에만 남아 bridge 위의 상단
                    // 실루엣을 보존한다.
                    PressedStripShape(
                        plateauHalfWidth: stripPlateauHalfWidth,
                        centerDepth: topInset,
                        // Glass 코너에서는 검정이 0까지 사라져, bridge가
                        // 화면 상단 꼭짓점의 둥근 면으로 직접 드러난다.
                        edgeDepth: usesSemanticGlass ? 0 : NotchGeometry.stripEdgeDepth
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
            // Keep Awake 상태는 별도 배지 창이 아니라 메인 도커 상단에 통합한다.
            .overlay(alignment: .top) { awakeStripStatus }
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
                    isNoteMode: $reveal.isNoteMode)
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
            // 노치에서 아래로 펼쳐지는 등장. 페이드 대신 상단 고정 확장을 쓴다.
            .scaleEffect(x: 1, y: reveal.revealed ? 1 : 0.4, anchor: .top)
            .opacity(reveal.revealed ? 1 : 0)
            // 창이 콘텐츠보다 커져도(픽셀 정렬 등) 여분은 항상 아래로 가고,
            // 형태 상단은 창 상단 = 화면 최상단에 밀착한다.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 메인 도커 왼쪽 plateau의 Keep Awake 상태. 커피 아이콘은 테마 블루,
    /// 시간은 고정 h:mm:ss이며 1초마다 갱신한다. 넓어진 문자열 때문에
    /// 아이콘이 왼쪽으로 밀리지 않도록 광학 위치를 오른쪽으로 보정한다.
    @ViewBuilder private var awakeStripStatus: some View {
        if let awakeSessionEnd {
            let sideWidth = NotchGeometry.stripPlateauSideWidth
            let notchHalf = stripPlateauHalfWidth - sideWidth
            GeometryReader { geo in
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 5) {
                        // Focus 위젯과 같은 번개. 켜져 있는 동안 상단 띠 왼쪽에 남은 시간과 함께 보인다.
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DS.accent)
                        Text(
                            KeepAwakePolicy.remainingClockLabel(
                                until: awakeSessionEnd, now: context.date)
                        )
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(width: sideWidth, height: topInset)
                    .position(
                        x: geo.size.width / 2 - notchHalf - sideWidth / 2
                            + NotchGeometry.awakeStatusOffsetX,
                        y: topInset / 2)
                }
            }
            .allowsHitTesting(false)
        }
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
                    .foregroundColor(dropTargeted ? DS.accent : .white.opacity(0.85))
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
                        info: "\(failedCount) item(s) could not be copied to Chap Drop.")
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
            HStack(alignment: .top, spacing: DS.spacing) {
                ForEach(Array(slots.enumerated()), id: \.offset) { column, slot in
                    slotView(slot)
                        .frame(width: width(for: slot), alignment: .leading)
                        // 모든 칸을 가장 긴 칸 높이로 늘려, 구분선이 내용 길이와 무관하게
                        // 항상 줄 전체 높이로 그려지게 한다.
                        .frame(maxHeight: .infinity, alignment: .top)
                        // 섹션 사이 얇은 세로 구분선. 폭 계산에 영향이 없도록 간격 중앙에 겹쳐 그린다.
                        .overlay(alignment: .leading) {
                            if column > 0 {
                                Rectangle()
                                    .fill(subtleSurface)
                                    .frame(width: 1)
                                    .padding(.vertical, 2)
                                    .offset(x: -DS.spacing / 2)
                                    .accessibilityHidden(true)
                            }
                        }
                }
            }
            // 칸 높이를 가장 긴 칸의 이상 높이로 고정해 무한 확장을 막는다.
            .fixedSize(horizontal: false, vertical: true)
            // 도커가 최소 폭보다 좁은 내용을 담으면 위젯 줄을 가운데에 둔다.
            .frame(maxWidth: .infinity, alignment: .center)
            // 메모 모드: 위젯 줄 자리를 도커 폭 전체의 넓은 메모장으로 바꾼다. 높이가 늘면
            // 컨트롤러가 창을 다시 맞춘다 (`resizePanelToFit`).
            .frame(minHeight: reveal.isNoteMode ? Self.noteModeHeight : 0, alignment: .top)
            .opacity(reveal.isNoteMode ? 0 : 1)
            .allowsHitTesting(!reveal.isNoteMode)
            .accessibilityHidden(reveal.isNoteMode)
            .overlay {
                if reveal.isNoteMode {
                    GeometryReader { geo in
                        NotchQuickNoteView(
                            palette: widgetPalette, showsHeader: false,
                            bodyHeight: max(geo.size.height - DS.notchHeaderHeight - 7, 60),
                            focusesOnAppear: true,
                            toolbar: NotchQuickNoteToolbar(
                                onDetach: {
                                    QuickNoteWindow.show()
                                    NotificationCenter.default.post(
                                        name: NotchLauncherController.requestClose, object: nil)
                                },
                                onClose: { reveal.isNoteMode = false }))
                    }
                    .transition(.opacity)
                }
            }

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
        .frame(minWidth: minWidth)
        .onAppear { refreshDropFiles() }
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

    @ViewBuilder
    private func slotView(_ slot: NotchSlotContent) -> some View {
        switch slot {
        case .launchers(let section):
            sectionView(section)
        case .screenshots:
            NotchScreenshotShelfView(
                backgroundHex: contrastBackgroundHex,
                usesSemanticForeground: usesSemanticGlass)
        case .downloads:
            NotchDownloadsShelfView(
                backgroundHex: contrastBackgroundHex,
                usesSemanticForeground: usesSemanticGlass)
        case .awake:
            NotchFocusView(palette: widgetPalette, sessionEnd: awakeSessionEnd)
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
            subtleSurface: subtleSurface)
    }

    private func sectionView(_ section: LauncherListSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // 제목을 누르면 그 타입이 선택된 설정창을 연다 (Screenshots 제목이 폴더를 여는 것과 같은 모양).
            NotchSectionTitleButton(
                symbol: LauncherListPolicy.symbolName(for: section.launchType),
                title: Self.sectionTitle(section.launchType),
                foreground: headingForeground,
                hoverBackground: rowHoverBackground,
                textShadowOpacity: textShadowOpacity
            ) {
                onOpenSettings(section.launchType)
            }

            if section.launchType == .app {
                appIconGrid(section)
            } else {
                launcherRows(section)
            }
        }
    }

    /// Apps 칸: 앱 아이콘 2열 격자. 단축키가 있으면 아이콘 모서리에 배지를 붙인다.
    private func appIconGrid(_ section: LauncherListSection) -> some View {
        // 고정 폭 열: flexible 열은 칸 폭(160pt)을 나눠 가져 아이콘 사이가 벌어진다.
        LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .fixed(NotchAppIconTile.tileSize), spacing: NotchAppIconTile.columnGap),
                count: LauncherListPolicy.appIconColumns),
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
        // 칸 폭 안에서 가운데, 앱 수와 관계없이 2열 × 3줄 자리를 잡아 목록 칸 4줄 높이와 맞춘다.
        .frame(maxWidth: .infinity)
        .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
    }

    private func launcherRows(_ section: LauncherListSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
        switch launchType {
        case .url: return "Sites"
        case .app: return "Apps"
        case .finder: return "Finder"
        }
    }
}

private struct NotchLauncherRow: View {
    let entry: LauncherListEntry
    let isOptionHeld: Bool
    let primaryForeground: Color
    let shortcutForeground: Color
    let textShadowOpacity: Double
    let hoverBackground: Color
    let keycapBackground: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(entry.site.name)
                    // 목록 본문은 Apple 기본 계층대로 regular. 섹션 헤더만
                    // semibold를 유지해 Glass에서 글자가 과하게 무거워지지 않는다.
                    .font(DS.notchBody)
                    .foregroundColor(primaryForeground)
                    .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
                    .lineLimit(1)
                Spacer(minLength: DS.spacingSmall)
                if let key = LauncherListPolicy.shortcutKey(for: entry.site) {
                    NotchKeycap(
                        key: key, isOptionHeld: isOptionHeld,
                        foreground: shortcutForeground, background: keycapBackground)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(LauncherListPolicy.shortcutBadge(for: entry.site) ?? "")
        .accessibilityLabel(LauncherListPolicy.launchAccessibilityLabel(for: entry.site))
    }
}

/// 단축키 키캡. 평소에는 키 글자만(`1`, `N`) 보여 읽기 쉽게 하고, ⌥를 누르고 있으면
/// 액센트로 강조하며 `⌥1`로 바뀌어 어떤 조합인지 알려준다. 폭은 `⌥1` 기준으로 잡아
/// 바뀌어도 줄이 움직이지 않는다.
struct NotchKeycap: View {
    let key: String
    let isOptionHeld: Bool
    let foreground: Color
    let background: Color
    var font: Font = DS.notchMeta.weight(.semibold)
    /// 목록 줄은 `⌥1` 폭을 미리 잡아 줄이 움직이지 않게 한다. 아이콘 배지는 아이콘을
    /// 덜 가리도록 글자 폭만 쓴다 (겹쳐 그리는 배지라 폭이 바뀌어도 배치가 움직이지 않는다).
    var reservesModifierWidth = true

    var body: some View {
        ZStack {
            if reservesModifierWidth {
                Text("⌥\(key)").font(font).hidden()
            }
            Text(isOptionHeld ? "⌥\(key)" : key)
                .font(font)
                .foregroundColor(isOptionHeld ? .white : foreground)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isOptionHeld ? DS.accent : background)
        )
        .animation(.easeOut(duration: 0.12), value: isOptionHeld)
        .accessibilityHidden(true)
    }
}

/// Apps 칸의 아이콘 한 개. 호버 시 앱 이름 툴팁과 옅은 배경을 보여준다.
struct NotchAppIconTile: View {
    let entry: LauncherListEntry
    let isOptionHeld: Bool
    let primaryForeground: Color
    let badgeForeground: Color
    let badgeBackground: Color
    let hoverBackground: Color
    let action: () -> Void

    @State private var icon: NSImage?
    @State private var isHovered = false

    init(
        entry: LauncherListEntry, isOptionHeld: Bool, primaryForeground: Color,
        badgeForeground: Color, badgeBackground: Color, hoverBackground: Color,
        action: @escaping () -> Void
    ) {
        self.entry = entry
        self.isOptionHeld = isOptionHeld
        self.primaryForeground = primaryForeground
        self.badgeForeground = badgeForeground
        self.badgeBackground = badgeBackground
        self.hoverBackground = hoverBackground
        self.action = action
        // 캐시에 있으면 첫 프레임부터 아이콘을 그린다 (재오픈·오프스크린 렌더).
        _icon = State(initialValue: entry.site.appPath.flatMap(AppIconLoader.cachedIcon))
    }

    // 격자 3줄(앱 6개)의 높이를 목록 칸 4줄(Sites·Finder 최대)과 정확히 맞춘다.
    // 목록 한 줄 = 13pt 본문 줄 높이 16pt + 위아래 여백 5pt씩, 줄 간격 3pt.
    static let listRowHeight: CGFloat = 26
    static let listRowSpacing: CGFloat = 3
    static let listBodyHeight: CGFloat = 4 * listRowHeight + 3 * listRowSpacing  // 113pt

    static let iconSize: CGFloat = 32
    /// 타일 한 변: 아이콘 + 호버 배경 여백 2pt씩.
    static let tileSize: CGFloat = iconSize + 2
    /// 가로 간격: 앱 아이콘의 투명 가장자리를 감안해 넉넉히 둔다.
    static let columnGap: CGFloat = 8
    /// 세로 간격: 3줄이 목록 4줄 높이를 정확히 채우도록 계산한다 (5.5pt).
    static let rowGap: CGFloat = (listBodyHeight - 3 * tileSize) / 2

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .foregroundColor(primaryForeground.opacity(0.5))
                            .padding(6)
                    }
                }
                .frame(width: Self.iconSize, height: Self.iconSize)
                .frame(width: Self.tileSize, height: Self.tileSize)

                if let key = LauncherListPolicy.shortcutKey(for: entry.site) {
                    // 목록과 같은 키캡. 아이콘 위에서도 읽히도록 반투명 재질을 깐다.
                    NotchKeycap(
                        key: key, isOptionHeld: isOptionHeld,
                        foreground: badgeForeground, background: badgeBackground,
                        font: DS.notchMeta.weight(.semibold),
                        reservesModifierWidth: false
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .offset(x: 3, y: 3)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(
            LauncherListPolicy.shortcutBadge(for: entry.site).map { "\(entry.site.name)  \($0)" }
                ?? entry.site.name
        )
        .accessibilityLabel(LauncherListPolicy.launchAccessibilityLabel(for: entry.site))
        .task(id: entry.site.appPath) {
            guard let path = entry.site.appPath, !path.isEmpty else { return }
            icon = AppIconLoader.cachedIcon(forAppPath: path)
            if icon == nil { icon = await AppIconLoader.icon(forAppPath: path) }
        }
    }
}

/// 모든 노치 도커가 공유하는 채움 스타일.
enum NotchDockStyle {
    /// 위는 진하게, 아래로 갈수록 사용자 불투명도로 흘러내리는 공통 페이드.
    static func fade(_ color: Color, bottomOpacity: Double) -> LinearGradient {
        // 중간 지점은 하단 값과 완전 불투명 사이를 보간해 자연스럽게 흘러내린다.
        let midOpacity = bottomOpacity + (1 - bottomOpacity) * 0.8
        return LinearGradient(
            stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(midOpacity), location: 0.35),
                .init(color: color.opacity(bottomOpacity), location: 1),
            ],
            startPoint: .top, endPoint: .bottom)
    }

    /// Liquid Glass 재질 레이어. macOS 26(Tahoe)+ 에서만 실제 유리가 되고,
    /// 그 이하에서는 빈 뷰라 아래의 색 페이드가 그대로 보인다 (black과 동일).
    ///
    /// 참고: https://developer.apple.com/design/human-interface-guidelines/materials
    @ViewBuilder
    static func liquidGlassLayer<S: Shape>(
        shape: S, material: NotchGlassMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            Group {
                switch material {
                case .clear:
                    // Clear는 뒤 화면이 그대로 비쳐 글자 대비가 떨어진다. 창 배경색(라이트는 흰색,
                    // 다크는 검정 계열)을 얇게 깔아 투명감은 두고 가독성만 끌어올린다.
                    Color.clear.glassEffect(.clear, in: Rectangle())
                        .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.28))
                case .regular:
                    Color.clear.glassEffect(.regular, in: Rectangle())
                }
            }
            // Glass의 광학 edge를 플레어 밖으로 밀어낸 뒤 원래 도커
            // 실루엣으로 잘라, 유리가 검정 꼭짓점까지 끊김 없이 닿게 한다.
            .padding(-NotchGeometry.glassEdgeBleed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(shape)
        }
    }

    /// "#RRGGBB" → Color. 형식이 어긋나면 검정.
    static func color(fromHex hex: String) -> Color {
        guard let valid = Config.validNotchPanelColorHex(hex) else { return .black }
        let value = UInt32(valid.dropFirst(), radix: 16) ?? 0
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    /// Color → "#RRGGBB". 설정 저장용.
    static func hex(from color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        return String(
            format: "#%02X%02X%02X",
            Int(round(ns.redComponent * 255)),
            Int(round(ns.greenComponent * 255)),
            Int(round(ns.blueComponent * 255)))
    }
}

/// Liquid Glass 전용 상단 코너 bridge. NotchDockShape의 오목 플레어가
/// 비워두는 좌우 코너를 채워, Glass 재질이 화면 상단의 검정 꼭짓점까지
/// 이어지게 한다. 검정 PressedStrip은 이 위에 그려져 기존 실루엣을 유지한다.
struct GlassCornerBridgeShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height)
        var path = Path()

        // 왼쪽: 상단 가로선 → 본체 벽 → 오목 arc를 거슬러 꼭짓점으로.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY + r), radius: r,
            startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
        path.closeSubpath()

        // 오른쪽 미러.
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// 노치 도크 실루엣. macOS 노치처럼 상단 모서리가 화면 상단 라인에서
/// 바깥으로 흐르는 오목 곡선으로 시작해 본체로 이어지고, 하단은 볼록하게 둥글다.
/// 본체 폭은 rect보다 상단 반경만큼 좁고, 오목 플레어가 rect 전체 폭까지 닿는다.
struct NotchDockShape: Shape {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    /// true면 상단 변을 닫지 않는다. 림 스트로크가 노치와 만나는 상단
    /// 라인에 흰 줄을 긋지 않도록 fill용(닫힘)과 분리한다.
    var isRim = false

    func path(in rect: CGRect) -> Path {
        let topR = topCornerRadius
        let bottomR = bottomCornerRadius
        var path = Path()

        // 상단 왼쪽 끝(화면 상단 라인)에서 시작.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // 왼쪽 오목 플레어: 상단 라인이 본체 왼쪽 벽으로 흘러내린다.
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY + topR), radius: topR,
            startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        // 본체 왼쪽 벽.
        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - bottomR))
        // 하단 왼쪽 볼록 모서리.
        path.addArc(
            center: CGPoint(x: rect.minX + topR + bottomR, y: rect.maxY - bottomR),
            radius: bottomR,
            startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        // 하단 변.
        path.addLine(to: CGPoint(x: rect.maxX - topR - bottomR, y: rect.maxY))
        // 하단 오른쪽 볼록 모서리.
        path.addArc(
            center: CGPoint(x: rect.maxX - topR - bottomR, y: rect.maxY - bottomR),
            radius: bottomR,
            startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        // 본체 오른쪽 벽.
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))
        // 오른쪽 오목 플레어: 본체 오른쪽 벽이 상단 라인으로 흘러나간다.
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + topR), radius: topR,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        // 림 모드에서는 상단 변을 긋지 않아 노치와의 경계가 검정으로 남는다.
        if !isRim { path.closeSubpath() }
        return path
    }
}

/// 노치가 배경을 눌러 만든 듯한 검정 띠. 노치·배지 plateau 구간은
/// `centerDepth`로 평평하게 깊고, 바깥으로는 코사인 감쇠로
/// `stripEdgeDepth`까지 부드럽게 얇아진다. 좁은 도커에서는 감쇠 구간이
/// 폭을 넘어 사실상 직선이 되고, 넓은 메인 도커에서 곡선이 드러난다.
struct PressedStripShape: Shape {
    let plateauHalfWidth: CGFloat
    let centerDepth: CGFloat
    /// 도커 외곽에서 남길 검정 깊이. Custom 기본은 6pt, Glass는 0으로
    /// 설정해 상단 둥근 코너가 Glass 재질로 보이게 한다.
    var edgeDepth: CGFloat = NotchGeometry.stripEdgeDepth

    func path(in rect: CGRect) -> Path {
        let edge = edgeDepth
        let falloff = NotchGeometry.stripFalloff
        let cx = rect.midX

        func depth(at x: CGFloat) -> CGFloat {
            let distance = abs(x - cx)
            if distance <= plateauHalfWidth { return centerDepth }
            let t = min((distance - plateauHalfWidth) / falloff, 1)
            // 코사인 반파: 1→0으로 부드럽게 감쇠.
            let factor = 0.5 + 0.5 * cos(t * .pi)
            return edge + (centerDepth - edge) * factor
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + depth(at: rect.maxX)))
        // 오른쪽→왼쪽으로 곡선 경계를 샘플링한다.
        let samples = 96
        for step in 0...samples {
            let x = rect.maxX - rect.width * CGFloat(step) / CGFloat(samples)
            path.addLine(to: CGPoint(x: x, y: rect.minY + depth(at: x)))
        }
        path.closeSubpath()
        return path
    }
}

/// 노치 칸 폭 계산용 글자 측정. 실제 글꼴(13pt 본문, 11pt semibold 제목)로 잰다.
enum NotchTextMetrics {
    private static let body = NSFont.systemFont(ofSize: 13)
    private static let label = NSFont.systemFont(ofSize: 11, weight: .semibold)
    private static let meta = NSFont.systemFont(ofSize: 10, weight: .medium)

    static func bodyWidth(_ text: String) -> CGFloat {
        // SwiftUI 렌더링은 AppKit 측정보다 1~2pt 넓게 그리므로 여유를 둔다.
        ceil((text as NSString).size(withAttributes: [.font: body]).width) + 3
    }

    /// 보조 정보(10pt medium) 폭. 스크린샷·다운로드 칸의 시각 문구에 쓴다.
    static func metaWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: meta]).width) + 2
    }

    static func labelWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: label]).width) + 2
    }

    /// 목록 한 줄: 좌우 여백 6 + 이름 + 최소 간격 8 + 키캡(글자 + 좌우 5).
    static func rowWidth(name: String, keycap: String?) -> CGFloat {
        let keycapWidth = keycap.map { labelWidth($0) - 2 + 8 + 8 } ?? 0
        return 12 + bodyWidth(name) + keycapWidth
    }

    /// 제목 줄: 좌우 여백 6 + 아이콘 약 13 + 간격 5 + 제목.
    static func headerWidth(title: String) -> CGFloat {
        12 + 13 + 5 + labelWidth(title)
    }
}

/// 런처 칸 제목. 호버 시 옅은 면과 › 표시, 누르면 설정창을 연다.
private struct NotchSectionTitleButton: View {
    let symbol: String
    let title: String
    let foreground: Color
    let hoverBackground: Color
    let textShadowOpacity: Double
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(DS.notchLabel)
                Text(title)
                    .font(DS.notchLabel)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(isHovered ? 1 : 0)
            }
            .foregroundColor(foreground)
            .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
            .padding(.horizontal, 6)
            .frame(height: DS.notchHeaderHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Edit \(title) in Settings")
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title) in Chap Settings")
        .accessibilityAddTraits(.isHeader)
    }
}

/// 도커 콘텐츠 크기를 창 컨트롤러로 올려 보내는 preference.
struct NotchContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
