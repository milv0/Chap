import SwiftUI

/// 탭 칸(Launchers·Apps)이 함께 쓰는 제목 줄. 제목 줄이 곧 탭이다: 고른 탭만 아이콘 + 이름,
/// 나머지는 흐린 아이콘만(`▢ Sites  ▤`). 아이콘을 누르면 그 탭으로 바꾼다. 고른 탭의 이름은 누를 수
/// 없고, 마우스를 올리면 보이는 ›만 그 탭의 설정을 연다. 탭을 바꾸려다 이름을 눌러 설정창이 뜨는
/// 일을 막는다. 탭 순서는 늘 같다. 탭이 하나면 제목만 남는다.
struct NotchTabHeader: View {
    struct Tab: Identifiable, Equatable {
        let id: String
        let symbol: String
        let title: String
    }

    let tabs: [Tab]
    let selectedID: String
    let palette: NotchWidgetPalette
    let onSelect: (String) -> Void
    let onOpenSelected: () -> Void

    var body: some View {
        HStack(spacing: LauncherListPolicy.launcherTabSpacing) {
            ForEach(tabs) { tab in
                if tab.id == selectedID {
                    // 고른 탭: 다른 칸 제목과 같은 모양이지만, 설정은 ›만 연다.
                    NotchTabTitle(
                        symbol: tab.symbol, title: tab.title, palette: palette,
                        onOpenSettings: onOpenSelected
                    )
                    .transition(.opacity)
                } else {
                    NotchTabIconButton(symbol: tab.symbol, title: tab.title, palette: palette) {
                        NSHapticFeedbackManager.defaultPerformer.perform(
                            .alignment, performanceTime: .now)
                        withAnimation(.easeOut(duration: 0.15)) { onSelect(tab.id) }
                    }
                }
            }
        }
        .frame(height: DS.notchHeaderHeight)
    }

    /// 칸 폭을 정할 제목 줄 폭: 가장 긴 제목이 골라졌을 때. 탭을 바꿔도 칸 폭이 흔들리지 않는다.
    static func widestTitleWidth(_ titles: [String]) -> Double {
        let longest = titles.map { NotchTextMetrics.headerWidth(title: $0) }.max() ?? 0
        return Double(longest) + LauncherListPolicy.launcherTitleAccessoryWidth
    }
}

/// Sites·Finder 목록을 한 칸에 두는 Launchers 칸. Apps는 아이콘 격자라 Apps 칸에 둔다.
/// 마지막으로 고른 탭을 기억한다. 칸 폭은 모든 탭 중 가장 넓은 내용에 맞춰 두어 탭을 바꿔도 도커가 흔들리지 않는다.
struct NotchLaunchersTabSlot<Content: View>: View {
    let sections: [LauncherListSection]
    let palette: NotchWidgetPalette
    let onOpenSettings: (LaunchType) -> Void
    @ViewBuilder let content: (LauncherListSection) -> Content

    @AppStorage(LauncherListPolicy.launcherTabStorageKey) private var storedTab = ""

    private var selected: LauncherListSection? {
        let type = LauncherListPolicy.selectedTab(
            stored: NotchLaunchersTabPreview.tab?.rawValue ?? storedTab,
            available: sections.map(\.launchType))
        return sections.first { $0.launchType == type }
    }

    var body: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 3) {
                NotchTabHeader(
                    tabs: sections.map {
                        .init(
                            id: $0.launchType.rawValue,
                            symbol: LauncherListPolicy.symbolName(for: $0.launchType),
                            title: LauncherListPolicy.title(for: $0.launchType))
                    },
                    selectedID: selected.launchType.rawValue,
                    palette: palette,
                    onSelect: { storedTab = $0 },
                    onOpenSelected: { onOpenSettings(selected.launchType) })
                content(selected)
                    .id(selected.launchType)
                    .transition(.opacity)
                    .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
                    .padding(.top, NotchAppIconTile.tabBodyTopGap)
            }
        }
    }
}

/// Apps(앱 아이콘 격자)와 Workspaces(작업 공간 타일)를 한 칸에 두는 Apps 칸. 둘 다 아이콘 타일이라
/// 탭을 바꿔도 칸 모양이 같다. 앱이 없으면 Workspaces만 보인다(Capture 타일이 늘 있다).
struct NotchAppsSlot<AppsContent: View, WorkspacesContent: View>: View {
    let hasApps: Bool
    let palette: NotchWidgetPalette
    let onOpenAppSettings: () -> Void
    let onOpenWorkspaceSettings: () -> Void
    @ViewBuilder let apps: () -> AppsContent
    @ViewBuilder let workspaces: () -> WorkspacesContent

    @AppStorage(AppsSlotTab.storageKey) private var storedTab = ""

    private var selected: AppsSlotTab {
        AppsSlotTab.selected(
            stored: NotchLaunchersTabPreview.appsTab?.rawValue ?? storedTab, hasApps: hasApps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            NotchTabHeader(
                tabs: AppsSlotTab.available(hasApps: hasApps).map {
                    .init(id: $0.rawValue, symbol: $0.symbol, title: $0.title)
                },
                selectedID: selected.rawValue,
                palette: palette,
                onSelect: { storedTab = $0 },
                onOpenSelected: {
                    selected == .apps ? onOpenAppSettings() : onOpenWorkspaceSettings()
                })
            Group {
                switch selected {
                case .apps: apps()
                case .workspaces: workspaces()
                }
            }
            .id(selected)
            .transition(.opacity)
            .frame(maxWidth: .infinity)
            .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
            .padding(.top, NotchAppIconTile.tabBodyTopGap)
        }
    }
}

/// 렌더 도구가 고르는 탭. 제네릭 뷰는 정적 저장 프로퍼티를 가질 수 없어 따로 둔다. 앱 실행 중에는 nil이다.
enum NotchLaunchersTabPreview {
    static var tab: LaunchType?
    static var appsTab: AppsSlotTab?
    /// 제목에 마우스를 올린 것처럼 ›를 그린다.
    static var titleHovered = false
}

/// 탭 칸의 고른 탭 제목. 아이콘 + 이름은 누를 수 없는 머리글이고, 제목에 마우스를 올리면 뒤에 ›가
/// 보인다. ›만 버튼이라 그 탭의 설정을 연다. 폭은 `NotchSectionTitleButton`과 같다
/// (오른쪽 여백 6 + `launcherTitleAccessoryWidth` 13 = › 버튼 18 + 간격 1).
private struct NotchTabTitle: View {
    let symbol: String
    let title: String
    let palette: NotchWidgetPalette
    let onOpenSettings: () -> Void

    @State private var isTitleHovered = false
    @State private var isChevronHovered = false

    var body: some View {
        HStack(spacing: 1) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(DS.notchLabel)
                    .foregroundColor(palette.icon ?? palette.heading)
                Text(title)
                    .font(DS.notchLabel)
                    .fixedSize()
            }
            .foregroundColor(palette.heading)
            .shadow(color: .black.opacity(palette.textShadowOpacity), radius: 1.5, y: 0.5)
            .padding(.leading, 6)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Button(action: onOpenSettings) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(palette.heading)
                    .opacity(
                        isChevronHovered
                            ? 1 : isTitleHovered || NotchLaunchersTabPreview.titleHovered ? 0.6 : 0
                    )
                    .frame(width: 18, height: DS.notchHeaderHeight)
                    .background(
                        RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                            .fill(isChevronHovered ? palette.hoverBackground : Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isChevronHovered = $0 }
            .help("Edit \(title) in Settings")
            .accessibilityLabel("Edit \(title) in Settings")
        }
        .frame(height: DS.notchHeaderHeight)
        .contentShape(Rectangle())
        .onHover { isTitleHovered = $0 }
    }
}

/// 탭 칸 제목 줄의 고르지 않은 탭(아이콘만). 흐린 제목색이고, 마우스를 올리면 진해지며
/// 옅은 면이 생긴다. 고른 탭은 아이콘 + 이름 제목(`NotchSectionTitleButton`)이 맡는다.
private struct NotchTabIconButton: View {
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
