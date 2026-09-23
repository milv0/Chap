import SwiftUI

/// 노치 아래에 펼쳐지는 런처 목록. 상태바 메뉴와 같은
/// `LauncherListPolicy` 결과를 그대로 렌더링한다.
///
/// 시각 언어는 "노치 확장"이다: 순수 검정 배경이 노치와 이어지고,
/// 하단 모서리만 둥글어 노치가 아래로 자라난 것처럼 보인다.
/// 검정 위 텍스트라 라이트/다크 모드와 무관하게 흰색 계열을 고정한다.
struct NotchLauncherPanelView: View {
    let width: CGFloat
    let sections: [LauncherListSection]
    let onLaunch: (Int) -> Void

    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacingSmall) {
            ForEach(sections, id: \.launchType) { section in
                sectionView(section)
            }
        }
        .padding(.horizontal, DS.paddingSmall)
        .padding(.top, 6)
        .padding(.bottom, DS.paddingSmall)
        .frame(width: width, alignment: .leading)
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
