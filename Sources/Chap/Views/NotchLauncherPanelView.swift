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
    let sections: [LauncherListSection]
    let onLaunch: (Int) -> Void

    @State private var revealed = false

    private static let columnWidth: CGFloat = 160
    /// 그림자가 창 경계에서 잘리지 않도록 검정 형태 주변에 두는 투명 여백.
    /// 그림자 확산(radius 9, y 4)이 이 여백 안에서 완전히 소멸해야
    /// 창 가장자리에 그림자 경계선이 생기지 않는다.
    static let shadowPadding: CGFloat = 28

    /// 패널 실루엣. 상단 모서리는 바깥으로 흐르는 오목 곡선이라
    /// 노치 도크가 상단바에서 빠져나온 것처럼 라인이 이어진다.
    private static var panelShape: NotchDockShape {
        NotchDockShape(topCornerRadius: 10, bottomCornerRadius: 20)
    }

    var body: some View {
        // 섹션을 좌우로 나란히 배치해 패널이 아래가 아니라 옆으로 길어진다.
        HStack(alignment: .top, spacing: DS.spacing) {
            ForEach(sections, id: \.launchType) { section in
                sectionView(section)
                    .frame(width: Self.columnWidth, alignment: .leading)
            }
        }
        .padding(.horizontal, DS.padding)
        .padding(.top, topInset + 8)
        .padding(.bottom, DS.paddingSmall)
        .frame(minWidth: minWidth)
        .background(
            Self.panelShape
                .fill(Color.black)
                // 어두운 배경에서 형태가 묻히지 않도록 잡아주는 미세한 림 하이라이트.
                .overlay(Self.panelShape.stroke(Color.white.opacity(0.08), lineWidth: 1))
                // 은은하게 띄우는 정도만. 강한 그림자는 상단바 주변에서 부자연스럽다.
                .shadow(color: .black.opacity(0.22), radius: 9, y: 4)
        )
        // 상단은 화면 모서리에 밀착해야 하므로 좌우·하단에만 그림자 여백을 둔다.
        .padding(.horizontal, Self.shadowPadding)
        .padding(.bottom, Self.shadowPadding)
        // 노치에서 아래로 펼쳐지는 등장. 페이드 대신 상단 고정 확장을 쓴다.
        .scaleEffect(x: 1, y: revealed ? 1 : 0.4, anchor: .top)
        .opacity(revealed ? 1 : 0)
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 26)) {
                revealed = true
            }
        }
    }

    private func sectionView(_ section: LauncherListSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(
                Self.sectionTitle(section.launchType),
                systemImage: LauncherListPolicy.symbolName(for: section.launchType)
            )
            .font(DS.captionFont)
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 6)

            ForEach(section.entries, id: \.siteIndex) { entry in
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
                    .font(DS.bodyFont)
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: DS.spacingSmall)
                if let shortcut = entry.site.shortcut, !shortcut.isEmpty {
                    Text("⌥ \(shortcut.uppercased())")
                        .font(DS.captionFont)
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.clear)
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
        path.closeSubpath()
        return path
    }
}
