import SwiftUI

/// Sites·Apps·Finder를 한 칸에 두는 Launchers 칸. 제목 줄 왼쪽은 고른 타입의 제목(누르면 설정),
/// 오른쪽은 항목이 있는 타입의 아이콘 탭이다. 탭 순서는 늘 같고, 고른 탭만 진하게 보인다.
/// 마지막으로 고른 탭을 기억한다. 칸 폭은 고정이라 탭을 바꿔도 도커가 흔들리지 않는다.
struct NotchLaunchersTabSlot<Content: View>: View {
    let sections: [LauncherListSection]
    let palette: NotchWidgetPalette
    let onOpenSettings: (LaunchType) -> Void
    @ViewBuilder let content: (LauncherListSection) -> Content

    /// (렌더 도구) 보여 줄 탭. 앱 실행 중에는 항상 nil이다.
    private static var previewTab: LaunchType? { NotchLaunchersTabPreview.tab }

    @AppStorage(LauncherListPolicy.launcherTabStorageKey) private var storedTab = ""

    private var selected: LauncherListSection? {
        let type = LauncherListPolicy.selectedTab(
            stored: Self.previewTab?.rawValue ?? storedTab,
            available: sections.map(\.launchType))
        return sections.first { $0.launchType == type }
    }

    var body: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 3) {
                header(selected)
                content(selected)
                    .id(selected.launchType)
                    .transition(.opacity)
                    // 목록(4줄)과 아이콘 격자 높이가 달라도 칸 바닥선이 그대로다.
                    .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
            }
        }
    }

    private func header(_ selected: LauncherListSection) -> some View {
        HStack(spacing: 0) {
            NotchSectionTitleButton(
                symbol: LauncherListPolicy.symbolName(for: selected.launchType),
                title: LauncherListPolicy.title(for: selected.launchType),
                foreground: palette.heading,
                iconForeground: palette.icon ?? palette.heading,
                hoverBackground: palette.hoverBackground,
                textShadowOpacity: palette.textShadowOpacity
            ) {
                onOpenSettings(selected.launchType)
            }
            Spacer(minLength: 8)
            if sections.count > 1 {
                HStack(spacing: 2) {
                    ForEach(sections, id: \.launchType) { section in
                        tab(
                            section.launchType,
                            isSelected: section.launchType == selected.launchType)
                    }
                }
                .padding(.trailing, 2)
            }
        }
        .frame(height: DS.notchHeaderHeight)
    }

    private func tab(_ type: LaunchType, isSelected: Bool) -> some View {
        NotchLauncherTabButton(
            symbol: LauncherListPolicy.symbolName(for: type),
            title: LauncherListPolicy.title(for: type),
            isSelected: isSelected,
            palette: palette
        ) {
            guard !isSelected else { return }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            withAnimation(.easeOut(duration: 0.12)) { storedTab = type.rawValue }
        }
    }
}

/// 렌더 도구가 고르는 탭. 제네릭 뷰는 정적 저장 프로퍼티를 가질 수 없어 따로 둔다.
enum NotchLaunchersTabPreview {
    static var tab: LaunchType?
}

/// Launchers 칸 제목 줄의 아이콘 탭 하나. 고른 탭은 아이콘 색, 나머지는 흐린 제목색.
/// 면이나 밑줄 없이 색만 바뀐다(미니멀). 마우스를 올리면 옅은 면이 생긴다.
private struct NotchLauncherTabButton: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let palette: NotchWidgetPalette
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(DS.notchLabel)
                .foregroundColor(
                    isSelected
                        ? (palette.icon ?? palette.heading)
                        : palette.heading.opacity(isHovered ? 0.85 : 0.4)
                )
                .frame(width: 22, height: DS.notchHeaderHeight)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                        .fill(isHovered && !isSelected ? palette.hoverBackground : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(isSelected ? title : "Show \(title)")
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
