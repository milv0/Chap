import SwiftUI

/// 탭 칸(Launchers·Apps)이 함께 쓰는 제목 줄. 제목 줄이 곧 탭이다: 고른 탭만 아이콘 + 이름,
/// 나머지는 흐린 아이콘만(`▢ Sites  ▤`). 아이콘을 누르면 그 탭으로 바꾼다. 제목 줄 오른쪽 빈 자리도
/// 누르면 옆 탭으로 바뀐다(작은 아이콘을 겨냥하지 않아도 된다, 마우스를 올리면 그 탭 아이콘이 진해진다).
/// 고른 탭의 이름은 누를 수 없고, 마우스를 올리면 보이는 ›만 그 탭의 설정을 연다. 탭 순서는 늘 같다.
/// 탭이 하나면 제목만 남는다. 트랙패드 두 손가락 가로 스와이프로도 넘긴다(`tabSwipe`).
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

    @State private var isFillerHovered = false

    /// 빈 자리를 누르면 갈 탭.
    private var neighborID: String? {
        TabStepPolicy.neighbor(ids: tabs.map(\.id), current: selectedID)
    }

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
                    NotchTabIconButton(
                        symbol: tab.symbol, title: tab.title, palette: palette,
                        isHighlighted: isFillerHovered && tab.id == neighborID
                    ) {
                        onSelect(tab.id)
                    }
                }
            }
            if let neighborID, tabs.count > 1 {
                // 제목 줄 남는 칸 전체가 옆 탭 버튼이다. 보이는 것은 없고, 마우스를 올리면 그 탭 아이콘이 반응한다.
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { isFillerHovered = $0 }
                    .onTapGesture { onSelect(neighborID) }
                    .accessibilityHidden(true)
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

/// 탭을 바꿀 때의 움직임. 넘기는 방향으로 본문이 조금 밀려 나가고 들어온다(칸 밖으로 넘치지 않는 14pt).
/// 끝에서 더 밀면 그 방향으로 살짝 튕기기만 한다.
struct NotchTabMotion {
    var forward = true
    var nudge: CGFloat = 0

    static let travel: CGFloat = 14

    var transition: AnyTransition {
        .asymmetric(
            insertion: .offset(x: forward ? Self.travel : -Self.travel).combined(with: .opacity),
            removal: .offset(x: forward ? -Self.travel : Self.travel).combined(with: .opacity))
    }

    /// `ids` 순서에서 `current` → `id`로 바꾼다. 방향을 먼저 정해 다음 틱에 바꿔야 나가는 본문도 그 방향으로 움직인다.
    static func select(
        _ id: String, from current: String, ids: [String], motion: Binding<NotchTabMotion>,
        apply: @escaping (String) -> Void
    ) {
        guard id != current else { return }
        let from = ids.firstIndex(of: current) ?? 0
        let to = ids.firstIndex(of: id) ?? 0
        motion.wrappedValue.forward = to > from
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) { apply(id) }
        }
    }

    /// 스와이프 한 번: 옆 탭이 있으면 넘기고, 없으면 튕긴다.
    static func step(
        _ step: Int, current: String, ids: [String], motion: Binding<NotchTabMotion>,
        apply: @escaping (String) -> Void
    ) {
        if let id = TabStepPolicy.target(ids: ids, current: current, step: step) {
            select(id, from: current, ids: ids, motion: motion, apply: apply)
        } else {
            withAnimation(.spring(duration: 0.12)) {
                motion.wrappedValue.nudge = CGFloat(-step) * 6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(duration: 0.25, bounce: 0.4)) {
                    motion.wrappedValue.nudge = 0
                }
            }
        }
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
    @State private var motion = NotchTabMotion()

    private var selected: LauncherListSection? {
        let type = LauncherListPolicy.selectedTab(
            stored: NotchLaunchersTabPreview.tab?.rawValue ?? storedTab,
            available: sections.map(\.launchType))
        return sections.first { $0.launchType == type }
    }

    private var ids: [String] { sections.map(\.launchType.rawValue) }

    var body: some View {
        if let selected {
            let current = selected.launchType.rawValue
            VStack(alignment: .leading, spacing: 3) {
                NotchTabHeader(
                    tabs: sections.map {
                        .init(
                            id: $0.launchType.rawValue,
                            symbol: LauncherListPolicy.symbolName(for: $0.launchType),
                            title: LauncherListPolicy.title(for: $0.launchType))
                    },
                    selectedID: current,
                    palette: palette,
                    onSelect: { id in
                        NotchTabMotion.select(
                            id, from: current, ids: ids, motion: $motion
                        ) { storedTab = $0 }
                    },
                    onOpenSelected: { onOpenSettings(selected.launchType) })
                content(selected)
                    .id(selected.launchType)
                    .transition(motion.transition)
                    .offset(x: motion.nudge)
                    .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
                    .padding(.top, NotchAppIconTile.tabBodyTopGap)
            }
            .tabSwipe(enabled: sections.count > 1) { step in
                NotchTabMotion.step(step, current: current, ids: ids, motion: $motion) {
                    storedTab = $0
                }
            }
        }
    }
}

/// Apps(앱 아이콘 격자)와 Layouts(창 배치 타일)를 한 칸에 두는 Apps 칸. 둘 다 아이콘 타일이라
/// 탭을 바꿔도 칸 모양이 같다. 앱이 없으면 Layouts만 보인다(Capture 타일이 늘 있다).
struct NotchAppsSlot<AppsContent: View, LayoutsContent: View>: View {
    let hasApps: Bool
    let palette: NotchWidgetPalette
    let onOpenAppSettings: () -> Void
    let onOpenLayoutSettings: () -> Void
    @ViewBuilder let apps: () -> AppsContent
    @ViewBuilder let layouts: () -> LayoutsContent

    @AppStorage(AppsSlotTab.storageKey) private var storedTab = ""
    @State private var motion = NotchTabMotion()

    private var selected: AppsSlotTab {
        AppsSlotTab.selected(
            stored: NotchLaunchersTabPreview.appsTab?.rawValue ?? storedTab, hasApps: hasApps)
    }

    private var ids: [String] { AppsSlotTab.available(hasApps: hasApps).map(\.rawValue) }

    var body: some View {
        let current = selected.rawValue
        VStack(alignment: .leading, spacing: 3) {
            NotchTabHeader(
                tabs: AppsSlotTab.available(hasApps: hasApps).map {
                    .init(id: $0.rawValue, symbol: $0.symbol, title: $0.title)
                },
                selectedID: current,
                palette: palette,
                onSelect: { id in
                    NotchTabMotion.select(id, from: current, ids: ids, motion: $motion) {
                        storedTab = $0
                    }
                },
                onOpenSelected: {
                    selected == .apps ? onOpenAppSettings() : onOpenLayoutSettings()
                })
            Group {
                switch selected {
                case .apps: apps()
                case .layouts: layouts()
                }
            }
            .id(selected)
            .transition(motion.transition)
            .offset(x: motion.nudge)
            .frame(maxWidth: .infinity)
            .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
            .padding(.top, NotchAppIconTile.tabBodyTopGap)
        }
        .tabSwipe(enabled: ids.count > 1) { step in
            NotchTabMotion.step(step, current: current, ids: ids, motion: $motion) {
                storedTab = $0
            }
        }
    }
}

/// 트랙패드 두 손가락 가로 스와이프. 칸 위에 마우스가 있는 동안만 스크롤 이벤트를 본다(공개 API인
/// `NSEvent` 로컬 모니터). 가로가 주된 정밀 스크롤만 다루고 삼키며, 세로 스크롤·일반 마우스 휠은 그대로 흘려보낸다.
private struct TabSwipeModifier: ViewModifier {
    let enabled: Bool
    let onStep: (Int) -> Void

    /// 모니터는 한 번 걸면 계속 같은 클로저를 부른다. 그 클로저가 처음 렌더의 `onStep`(그때의 현재 탭)을
    /// 붙잡으면 두 번째 스와이프부터 넘어가지 않는다. 매 렌더 최신 `onStep`을 이 상자에 넣고 모니터는 상자를 본다.
    @State private var box = SwipeBox()

    func body(content: Content) -> some View {
        box.onStep = onStep
        return
            content
            .contentShape(Rectangle())
            .onHover { inside in
                if inside && enabled { box.install() } else { box.remove() }
            }
            .onDisappear { box.remove() }
    }
}

/// 스와이프 모니터와 상태를 담는 참조 상자(메인 스레드 전용).
private final class SwipeBox {
    var onStep: (Int) -> Void = { _ in }
    private var monitor: Any?
    private var tracker = TabSwipeTracker()

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        tracker = TabSwipeTracker()
    }

    deinit { remove() }

    /// 탭 칸이 이 이벤트를 다뤘으면 true(삼킨다).
    private func handle(_ event: NSEvent) -> Bool {
        guard event.hasPreciseScrollingDeltas else { return false }
        let phase: TabSwipeTracker.Phase
        if !event.momentumPhase.isEmpty {
            phase = .momentum
        } else if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else {
            phase = .other
        }
        let dx = TabSwipeTracker.fingerDX(
            scrollingDeltaX: Double(event.scrollingDeltaX),
            directionInverted: event.isDirectionInvertedFromDevice)
        let dy = Double(event.scrollingDeltaY)
        if let step = tracker.step(phase: phase, fingerDX: dx, deltaY: dy) {
            onStep(step)
        }
        return phase == .momentum
            ? TabSwipeTracker.isHorizontal(deltaX: dx, deltaY: dy)
            : (phase == .began || phase == .changed)
                && TabSwipeTracker.isHorizontal(deltaX: dx, deltaY: dy)
    }
}

extension View {
    /// 트랙패드 가로 스와이프로 탭을 넘긴다. `onStep`은 +1(다음)·-1(이전).
    func tabSwipe(enabled: Bool, onStep: @escaping (Int) -> Void) -> some View {
        modifier(TabSwipeModifier(enabled: enabled, onStep: onStep))
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
    /// 제목 줄 빈 자리에 마우스가 있을 때: 누르면 이 탭으로 간다는 것을 아이콘으로 알린다.
    var isHighlighted = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(DS.notchLabel)
                .foregroundColor(
                    palette.heading.opacity(isHovered ? 0.85 : isHighlighted ? 0.7 : 0.4)
                )
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
