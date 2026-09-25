import SwiftUI

/// 노치 패널 한 칸의 렌더링 내용.
enum NotchSlotContent {
    /// 런처 목록 위젯.
    case launchers(LauncherListSection)
    /// 스크린샷 선반 위젯.
    case screenshots([URL])
}

/// 패널 펼침/접힘 상태와 실시간 조절 값. 컨트롤러가 접힘 애니메이션과
/// 불투명도 프리뷰를 구동할 수 있도록 뷰 외부에서 관찰 가능한 모델로 둔다.
final class NotchRevealModel: ObservableObject {
    @Published var revealed = false
    @Published var bottomOpacity: Double = Config.notchPanelOpacityDefault
    @Published var colorHex: String = Config.notchPanelColorHexDefault
    /// 파일 드래그가 노치에 닿아 "Drop here" 레이어를 덮어야 하는 상태.
    @Published var isDropTargetActive = false
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
    /// Keep Awake 세션 종료 시각. 활성 중이면 왼쪽 상단 영역에 h:mm으로 표시.
    let awakeSessionEnd: Date?
    /// 시각 스타일. Custom은 색상·불투명도 도크, Glass는 시스템 재질.
    let style: NotchPanelStyle
    /// Apple 공식 Glass.clear/regular 재질 변형.
    let glassMaterial: NotchGlassMaterial
    /// 배치된 위젯 칸들 (빈 칸 제외, 왼쪽부터).
    let slots: [NotchSlotContent]
    let onLaunch: (Int) -> Void
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

    /// 스타일별 채움. Custom은 사용자가 고른 색·불투명도 페이드,
    /// Glass는 뒤 콘텐츠를 굴절시켜야 하므로 투명한 기반을 쓴다.
    private var panelFill: AnyShapeStyle {
        switch style {
        case .custom:
            return AnyShapeStyle(
                NotchDockStyle.fade(
                    NotchDockStyle.color(fromHex: reveal.colorHex),
                    bottomOpacity: reveal.bottomOpacity))
        case .glass:
            return AnyShapeStyle(Color.clear)
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
                    if style == .glass {
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
                        edgeDepth: style == .glass ? 0 : NotchGeometry.stripEdgeDepth
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
            // 파일 드래그 중에는 도커 전체를 덮는 반투명 Drop here 레이어.
            .overlay { dropOverlay }
            // 상단은 화면 모서리에 밀착해야 하므로 좌우·하단에만 그림자 여백을 둔다.
            .padding(.horizontal, Self.shadowPadding)
            .padding(.bottom, Self.shadowPadding)
            // 노치에서 아래로 펼쳐지는 등장. 페이드 대신 상단 고정 확장을 쓴다.
            .scaleEffect(x: 1, y: reveal.revealed ? 1 : 0.4, anchor: .top)
            .opacity(reveal.revealed ? 1 : 0)
            // 창이 콘텐츠보다 커져도(픽셀 정렬 등) 여분은 항상 아래로 가고,
            // 형태 상단은 창 상단 = 화면 최상단에 밀착한다.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 메인 도커 왼쪽 plateau의 Keep Awake 상태. 커피 아이콘은 테마 블루,
    /// 시간은 고정 h:mm이며 영역 중심에서 오른쪽으로 5pt 이동한다.
    @ViewBuilder private var awakeStripStatus: some View {
        if let awakeSessionEnd {
            let sideWidth = NotchGeometry.stripPlateauSideWidth
            let notchHalf = stripPlateauHalfWidth - sideWidth
            GeometryReader { geo in
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    HStack(spacing: 5) {
                        Image(systemName: "cup.and.saucer.fill")
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
            let stored = ChapDrop.store(urls)
            reveal.isDropTargetActive = false
            return !stored.isEmpty
        } isTargeted: {
            dropTargeted = $0
        }
    }

    @State private var dropFiles: [URL] = []

    /// 전경 대비 계산용 배경색. Glass는 색을 깔지 않으므로 어두운 재질로
    /// 취급해 검정 기준 전경값을 그대로 쓴다.
    private var contrastBackgroundHex: String {
        style == .glass ? Config.notchPanelColorHexDefault : reveal.colorHex
    }

    /// Glass에서는 시스템 semantic 색이 재질의 vibrancy와 배경에 맞춰
    /// 자동 적응한다. 비-Glass는 기존 고대비 흰색 체계를 유지한다.
    private var primaryForeground: Color {
        // Apple 기본 계층: 콘텐츠 이름은 semantic primary 그대로 사용한다.
        // 시스템이 Liquid Glass와 활성 appearance에 맞춰 색·vibrancy를 결정한다.
        style == .glass ? Color.primary : .white.opacity(0.96)
    }

    private var secondaryForeground: Color {
        style == .glass
            ? Color.secondary
            : .white.opacity(
                NotchContrastPolicy.secondaryTextOpacity(
                    backgroundHex: contrastBackgroundHex))
    }

    private var accentForeground: Color {
        // Glass에서도 기능 구분 아이콘은 Chap 액센트 블루를 유지한다.
        // 의미는 옆 텍스트가 중복 전달하므로 색만으로 정보를 구분하지 않는다.
        if style == .glass { return DS.accent }
        return NotchContrastPolicy.usesAccentForeground(
            backgroundHex: contrastBackgroundHex)
            ? DS.accent : .white.opacity(0.95)
    }

    /// Glass 재질 위에는 시스템 vibrancy가 대비를 담당하므로 검정 그림자를
    /// 넣지 않는다. 비-Glass에서만 기존 윤곽 보정을 유지한다.
    private var textShadowOpacity: Double { style == .glass ? 0 : 0.75 }

    /// Apple식 hover: Glass에서는 semantic primary의 8% 회색 면이
    /// appearance에 맞춰 적응하고, 다른 스타일은 기존 흰색 면을 유지한다.
    private var rowHoverBackground: Color {
        style == .glass ? Color.primary.opacity(0.08) : .white.opacity(0.16)
    }

    /// 섹션 콘텐츠 본문. 하단에 Chap Drop 파일 행이 조건부로 붙는다.
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DS.spacingSmall) {
            // 위젯 칸을 좌우로 나란히 배치해 패널이 아래가 아니라 옆으로 길어진다.
            HStack(alignment: .top, spacing: DS.spacing) {
                ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                    slotView(slot)
                        .frame(width: Self.columnWidth, alignment: .leading)
                }
            }

            // Chap Drop 파일 행. 파일이 없으면 섹션 자체가 사라져
            // 도커는 원래 크기로 돌아간다.
            if !dropFiles.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .padding(.top, 2)
                HStack(alignment: .top, spacing: DS.spacingSmall) {
                    ForEach(dropFiles, id: \.self) { url in
                        NotchDropFileItem(
                            url: url,
                            primaryForeground: primaryForeground,
                            textShadowOpacity: textShadowOpacity,
                            hoverBackground: rowHoverBackground
                        ) {
                            ChapDrop.remove(url)
                            dropFiles = ChapDrop.recentFiles(
                                limit: DropPolicy.maxDockItems)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.padding)
        .padding(.top, topInset + NotchGeometry.contentTopGap)
        .padding(.bottom, DS.paddingSmall)
        .frame(minWidth: minWidth)
        .onAppear { dropFiles = ChapDrop.recentFiles(limit: DropPolicy.maxDockItems) }
        .onReceive(
            NotificationCenter.default.publisher(for: ChapDrop.didChangeNotification)
        ) { _ in
            dropFiles = ChapDrop.recentFiles(limit: DropPolicy.maxDockItems)
        }
    }

    @ViewBuilder
    private func slotView(_ slot: NotchSlotContent) -> some View {
        switch slot {
        case .launchers(let section):
            sectionView(section)
        case .screenshots(let urls):
            NotchScreenshotShelfView(
                urls: urls, backgroundHex: contrastBackgroundHex,
                usesSemanticForeground: style == .glass)
        }
    }

    private func sectionView(_ section: LauncherListSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // 아이콘은 스캔 앵커. 배경과의 대비가 HIG 비텍스트 최소치에
            // 미달하면(예: 파란 배경) 액센트 대신 흰색을 쓴다.
            HStack(spacing: 5) {
                Image(systemName: LauncherListPolicy.symbolName(for: section.launchType))
                    .font(DS.captionFont)
                    .foregroundColor(accentForeground)
                Text(Self.sectionTitle(section.launchType))
                    .font(DS.captionFont.weight(.semibold))
                    .foregroundColor(secondaryForeground)
            }
            .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
            .padding(.horizontal, 6)
            .padding(.bottom, 1)

            ForEach(
                section.entries.prefix(LauncherListPolicy.maxEntriesPerNotchSlot),
                id: \.siteIndex
            ) { entry in
                NotchLauncherRow(
                    entry: entry,
                    primaryForeground: primaryForeground,
                    shortcutForeground: style == .glass
                        ? Color.secondary
                        : .white.opacity(
                            NotchContrastPolicy.tertiaryTextOpacity(
                                backgroundHex: contrastBackgroundHex)),
                    textShadowOpacity: textShadowOpacity,
                    hoverBackground: rowHoverBackground
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
        case .finder: return "Folders"
        case .shell: return "Scripts"
        }
    }
}

private struct NotchLauncherRow: View {
    let entry: LauncherListEntry
    let primaryForeground: Color
    let shortcutForeground: Color
    let textShadowOpacity: Double
    let hoverBackground: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(entry.site.name)
                    // 목록 본문은 Apple 기본 계층대로 regular. 섹션 헤더만
                    // semibold를 유지해 Glass에서 글자가 과하게 무거워지지 않는다.
                    .font(DS.bodyFont)
                    .foregroundColor(primaryForeground)
                    .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
                    .lineLimit(1)
                Spacer(minLength: DS.spacingSmall)
                if let shortcut = entry.site.shortcut, !shortcut.isEmpty {
                    // 키캡 칩: 옅은 회색 글자보다 배경 대비로 읽히게 한다.
                    Text("⌥\(shortcut.uppercased())")
                        .font(DS.captionFont.weight(.medium))
                        .foregroundColor(shortcutForeground)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
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
        .accessibilityLabel("Launch \(entry.site.name)")
    }
}

/// 모든 노치 도커가 공유하는 채움 스타일.
enum NotchDockStyle {
    /// 도커 배경 2층 구조: 상단바 구간(topInset)은 노치의 연장이라 항상
    /// 완전 검정, 노치 하단 경계 아래 콘텐츠 박스는 커스텀 색이 기존
    /// 페이드(아래로 갈수록 사용자 불투명도)로 흘러내린다.
    @ViewBuilder
    static func dockBackground<S: Shape>(
        shape: S, topInset: CGFloat, stripPlateauHalfWidth: CGFloat,
        colorHex: String, bottomOpacity: Double
    ) -> some View {
        ZStack(alignment: .top) {
            shape.fill(fade(color(fromHex: colorHex), bottomOpacity: bottomOpacity))
            PressedStripShape(
                plateauHalfWidth: stripPlateauHalfWidth, centerDepth: topInset
            )
            .fill(Color.black)
        }
        .clipShape(shape)
    }

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
                    Color.clear.glassEffect(.clear, in: Rectangle())
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
