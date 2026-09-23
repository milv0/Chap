import SwiftUI

/// 노치 아래에 펼쳐지는 런처 목록. 상태바 메뉴와 같은
/// `LauncherListPolicy` 결과를 그대로 렌더링한다.
struct NotchLauncherPanelView: View {
    let sections: [LauncherListSection]
    let onLaunch: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacingSmall) {
            ForEach(sections, id: \.launchType) { section in
                sectionView(section)
            }
        }
        .padding(DS.paddingSmall)
        .frame(width: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                .fill(DS.surfaceBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius, style: .continuous)
                .strokeBorder(DS.border, lineWidth: 1)
        )
    }

    private func sectionView(_ section: LauncherListSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(
                Self.sectionTitle(section.launchType),
                systemImage: LauncherListPolicy.symbolName(for: section.launchType)
            )
            .font(DS.captionFont)
            .foregroundColor(DS.textTertiary)
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
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: DS.spacingSmall)
                if let shortcut = entry.site.shortcut, !shortcut.isEmpty {
                    Text("⌥ \(shortcut.uppercased())")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? DS.accentSurface : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Launch \(entry.site.name)")
    }
}
