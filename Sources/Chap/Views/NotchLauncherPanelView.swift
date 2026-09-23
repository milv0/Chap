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
            UnevenRoundedRectangle(
                bottomLeadingRadius: 18, bottomTrailingRadius: 18, style: .continuous
            )
            .fill(Color.black)
        )
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
