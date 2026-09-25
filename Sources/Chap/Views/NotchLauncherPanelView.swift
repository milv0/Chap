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
    /// 시각 스타일. black은 노치 확장 도크, iceberg는 뾰족한 얼음 도크.
    let style: NotchPanelStyle
    /// 배치된 위젯 칸들 (빈 칸 제외, 왼쪽부터).
    let slots: [NotchSlotContent]
    let onLaunch: (Int) -> Void
    @ObservedObject var reveal: NotchRevealModel

    /// 원래의 모션: 패널 전체가 노치 상단 기준으로 스프링 확장하고,
    /// 접힘은 빠른 페이드로 정리한다. stiffness 440은 약 0.3초에 정착하고,
    /// damping 30은 기존(320/26)과 같은 감쇠 비율이라 바운스 느낌은 유지된다.
    static let openAnimation: Animation = .interpolatingSpring(stiffness: 440, damping: 30)
    static let closeAnimation: Animation = .smooth(duration: 0.18)

    private static let columnWidth: CGFloat = 160
    /// 그림자가 창 경계에서 잘리지 않도록 검정 형태 주변에 두는 투명 여백.
    /// 그림자 확산(radius 9, y 4)이 이 여백 안에서 완전히 소멸해야
    /// 창 가장자리에 그림자 경계선이 생기지 않는다.
    static let shadowPadding: CGFloat = 28
    /// 빙하 스타일의 톱니 최대 깊이. 콘텐츠가 톱니를 침범하지 않게 여백에 더한다.
    private static let icebergJagDepth: CGFloat = 46

    /// 패널 실루엣. 상단 모서리는 바깥으로 흐르는 오목 곡선이라
    /// 노치 도크가 상단바에서 빠져나온 것처럼 라인이 이어진다.
    private var panelShape: AnyShape {
        switch style {
        case .black:
            return AnyShape(NotchDockShape(topCornerRadius: 10, bottomCornerRadius: 20))
        case .iceberg:
            return AnyShape(
                IcebergDockShape(topCornerRadius: 10, jagDepth: Self.icebergJagDepth))
        }
    }

    /// 림 스트로크용 실루엣. 상단 변이 열려 있어 노치 경계에 흰 줄이 생기지 않는다.
    private var rimShape: AnyShape {
        switch style {
        case .black:
            return AnyShape(
                NotchDockShape(topCornerRadius: 10, bottomCornerRadius: 20, isRim: true))
        case .iceberg:
            return AnyShape(
                IcebergDockShape(
                    topCornerRadius: 10, jagDepth: Self.icebergJagDepth, isRim: true))
        }
    }

    /// 스타일별 채움. black은 노치를 감싸는 상단은 완전 검정으로 유지하고
    /// 아래로 갈수록 투명해져 배경과 부드럽게 섞인다. iceberg는 노치와
    /// 만나는 상단은 검정에 가깝게, 아래로 갈수록 얼음빛 파랑으로 깊어진다.
    private var panelFill: AnyShapeStyle {
        switch style {
        case .black:
            // 중간 지점은 하단 값과 완전 검정 사이를 보간해 자연스럽게 흘러내린다.
            let bottomOpacity = reveal.bottomOpacity
            let midOpacity = bottomOpacity + (1 - bottomOpacity) * 0.8
            return AnyShapeStyle(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(midOpacity), location: 0.35),
                        .init(color: .black.opacity(bottomOpacity), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom))
        case .iceberg:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 16 / 255, green: 38 / 255, blue: 72 / 255),
                        Color(red: 62 / 255, green: 122 / 255, blue: 190 / 255),
                    ],
                    startPoint: .top, endPoint: .bottom))
        }
    }

    var body: some View {
        contentBody
            .background(
                panelShape
                    .fill(panelFill)
                    // 어두운 배경에서 형태가 묻히지 않도록 잡아주는 미세한 림 하이라이트.
                    // 상단 변이 열린 rim 형태라 노치 경계에는 줄이 없다.
                    .overlay(rimShape.stroke(Color.white.opacity(0.08), lineWidth: 1))
                    // 은은하게 띄우는 정도만. 강한 그림자는 상단바 주변에서 부자연스럽다.
                    .shadow(color: .black.opacity(0.22), radius: 9, y: 4)
            )
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

    /// 섹션 콘텐츠 본문.
    private var contentBody: some View {
        // 위젯 칸을 좌우로 나란히 배치해 패널이 아래가 아니라 옆으로 길어진다.
        HStack(alignment: .top, spacing: DS.spacing) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                slotView(slot)
                    .frame(width: Self.columnWidth, alignment: .leading)
            }
        }
        .padding(.horizontal, DS.padding)
        .padding(.top, topInset + 8)
        .padding(
            .bottom,
            style == .iceberg ? DS.paddingSmall + Self.icebergJagDepth : DS.paddingSmall
        )
        .frame(minWidth: minWidth)
    }

    @ViewBuilder
    private func slotView(_ slot: NotchSlotContent) -> some View {
        switch slot {
        case .launchers(let section):
            sectionView(section)
        case .screenshots(let urls):
            NotchScreenshotShelfView(urls: urls)
        }
    }

    private func sectionView(_ section: LauncherListSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // 아이콘은 테마 블루로 스캔 앵커 역할, 라벨은 대비를 높인 보조 흰색.
            HStack(spacing: 5) {
                Image(systemName: LauncherListPolicy.symbolName(for: section.launchType))
                    .font(DS.captionFont)
                    .foregroundColor(DS.accent)
                Text(Self.sectionTitle(section.launchType))
                    .font(DS.captionFont.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))
            }
            .shadow(color: .black.opacity(0.75), radius: 1.5, y: 0.5)
            .padding(.horizontal, 6)
            .padding(.bottom, 1)

            ForEach(
                section.entries.prefix(LauncherListPolicy.maxEntriesPerNotchSlot),
                id: \.siteIndex
            ) { entry in
                NotchLauncherRow(entry: entry) {
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
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(entry.site.name)
                    .font(DS.bodyFont.weight(.medium))
                    .foregroundColor(.white.opacity(0.96))
                    .shadow(color: .black.opacity(0.75), radius: 1.5, y: 0.5)
                    .lineLimit(1)
                Spacer(minLength: DS.spacingSmall)
                if let shortcut = entry.site.shortcut, !shortcut.isEmpty {
                    // 키캡 칩: 옅은 회색 글자보다 배경 대비로 읽히게 한다.
                    Text("⌥\(shortcut.uppercased())")
                        .font(DS.captionFont.weight(.medium))
                        .foregroundColor(.white.opacity(0.75))
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
                    .fill(isHovered ? Color.white.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Launch \(entry.site.name)")
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

/// 빙하 도크 실루엣. 상단 오목 플레어는 NotchDockShape과 같고,
/// 하단은 빙하 아랫부분처럼 깊이가 불규칙한 톱니로 끝난다.
/// 톱니 패턴은 결정적이라 열 때마다 모양이 흔들리지 않는다.
struct IcebergDockShape: Shape {
    let topCornerRadius: CGFloat
    /// 톱니 최대 깊이. 각 꼭짓점은 패턴 비율만큼 이 깊이에 도달한다.
    let jagDepth: CGFloat
    /// true면 상단 변을 닫지 않는다 (NotchDockShape.isRim과 동일한 역할).
    var isRim = false

    /// 연속된 톱니 꼭짓점의 상대 깊이. 자연스럽게 보이도록 불규칙하게 섞는다.
    private static let depthPattern: [CGFloat] = [0.85, 0.45, 1.0, 0.55, 0.75, 0.35, 0.9, 0.6]
    private static let targetToothWidth: CGFloat = 68

    func path(in rect: CGRect) -> Path {
        let topR = topCornerRadius
        let baseY = rect.maxY - jagDepth
        let leftX = rect.minX + topR
        let rightX = rect.maxX - topR
        var path = Path()

        // 상단 왼쪽 끝(화면 상단 라인)에서 시작해 오목 플레어로 본체에 진입.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY + topR), radius: topR,
            startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        // 본체 왼쪽 벽은 톱니 기준선까지 내려간다.
        path.addLine(to: CGPoint(x: leftX, y: baseY))

        // 하단 톱니: 목표 폭에 맞춰 개수를 정하고 패턴 깊이로 꼭짓점을 찍는다.
        let bodyWidth = rightX - leftX
        let teeth = max(3, Int((bodyWidth / Self.targetToothWidth).rounded()))
        let toothWidth = bodyWidth / CGFloat(teeth)
        for tooth in 0..<teeth {
            let depth = Self.depthPattern[tooth % Self.depthPattern.count]
            let tipX = leftX + toothWidth * (CGFloat(tooth) + 0.5)
            let endX = leftX + toothWidth * CGFloat(tooth + 1)
            path.addLine(to: CGPoint(x: tipX, y: baseY + jagDepth * depth))
            path.addLine(to: CGPoint(x: endX, y: baseY))
        }

        // 본체 오른쪽 벽을 올라가 오목 플레어로 상단 라인에 합류.
        path.addLine(to: CGPoint(x: rightX, y: rect.minY + topR))
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + topR), radius: topR,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        // 림 모드에서는 상단 변을 긋지 않아 노치와의 경계가 검정으로 남는다.
        if !isRim { path.closeSubpath() }
        return path
    }
}
