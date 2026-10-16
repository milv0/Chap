import SwiftUI

/// Sites·Apps·Finder를 한 칸에 두는 Launchers 칸. 제목 줄이 곧 탭이다: 고른 탭만 아이콘 + 이름,
/// 나머지는 아이콘만(`▢ Sites  ■  ▤`). 아이콘을 누르면 그 탭으로 바꾸고, 고른 탭을 다시 누르면
/// 그 타입의 설정을 연다(마우스를 올리면 ›). 탭 순서는 launch type 순서로 늘 같다.
/// 마지막으로 고른 탭을 기억한다. 칸 폭은 모든 탭 중 가장 넓은 내용에 맞춰 두어 탭을 바꿔도 도커가 흔들리지 않는다.
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
        HStack(spacing: LauncherListPolicy.launcherTabSpacing) {
            ForEach(sections, id: \.launchType) { section in
                if section.launchType == selected.launchType {
                    // 고른 탭: 다른 칸 제목과 같은 모양. 누르면 그 타입의 설정을 연다.
                    NotchSectionTitleButton(
                        symbol: LauncherListPolicy.symbolName(for: section.launchType),
                        title: LauncherListPolicy.title(for: section.launchType),
                        foreground: palette.heading,
                        iconForeground: palette.icon ?? palette.heading,
                        hoverBackground: palette.hoverBackground,
                        textShadowOpacity: palette.textShadowOpacity
                    ) {
                        onOpenSettings(section.launchType)
                    }
                    .transition(.opacity)
                } else {
                    NotchLauncherTabButton(
                        symbol: LauncherListPolicy.symbolName(for: section.launchType),
                        title: LauncherListPolicy.title(for: section.launchType),
                        palette: palette
                    ) {
                        select(section.launchType)
                    }
                }
            }
        }
        .frame(height: DS.notchHeaderHeight)
    }

    private func select(_ type: LaunchType) {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        withAnimation(.easeOut(duration: 0.15)) { storedTab = type.rawValue }
    }
}

/// 렌더 도구가 고르는 탭. 제네릭 뷰는 정적 저장 프로퍼티를 가질 수 없어 따로 둔다.
enum NotchLaunchersTabPreview {
    static var tab: LaunchType?
}

/// Launchers 칸 제목 줄의 고르지 않은 탭(아이콘만). 흐린 제목색이고, 마우스를 올리면 진해지며
/// 옅은 면이 생긴다. 고른 탭은 아이콘 + 이름 제목(`NotchSectionTitleButton`)이 맡는다.
private struct NotchLauncherTabButton: View {
    let symbol: String
    let title: String
    let palette: NotchWidgetPalette
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(DS.notchLabel)
                .foregroundColor(palette.heading.opacity(isHovered ? 0.85 : 0.4))
                .frame(width: LauncherListPolicy.launcherTabWidth, height: DS.notchHeaderHeight)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                        .fill(isHovered ? palette.hoverBackground : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Show \(title)")
        .accessibilityLabel("Show \(title)")
    }
}
