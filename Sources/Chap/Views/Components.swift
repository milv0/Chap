import Cocoa
import SwiftUI

// MARK: - Sidebar Item

struct SidebarItem: View {
    let icon: String
    let name: String
    let badge: String?
    let isSelected: Bool
    @State private var isHovered = false

    init(
        icon: String, name: String, badge: String? = nil,
        isSelected: Bool = false
    ) {
        self.icon = icon
        self.name = name
        self.badge = badge
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? DS.accent : DS.textSecondary)
                .frame(width: 20)
            Text(name)
                .font(DS.bodyFont)
                .foregroundColor(DS.textPrimary)
                .lineLimit(1)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(DS.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DS.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, DS.paddingSmall)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? DS.accentSoft
                : (isHovered ? DS.border.opacity(0.3) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Onboarding Card

struct OnboardingCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(DS.accent)
                .frame(width: 36, height: 36)
                .background(DS.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DS.headlineFont)
                    .foregroundColor(DS.textPrimary)
                Text(description)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(DS.paddingSmall)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
    }
}

// MARK: - Sidebar Drop Delegate

struct SidebarDropDelegate: DropDelegate {
    let currentIndex: Int
    @Binding var sites: [Site]
    @Binding var selectedIndex: Int?
    let onDrop: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.plainText]).first else { return false }
        _ = item.loadObject(ofClass: String.self) { str, _ in
            guard let str = str, let from = Int(str) else { return }
            DispatchQueue.main.async {
                guard from != self.currentIndex,
                    from < self.sites.count, self.currentIndex < self.sites.count,
                    self.sites[from].launchType == self.sites[self.currentIndex].launchType
                else { return }
                // from < currentIndex이면 remove로 뒤 요소가 한 칸 당겨지므로
                // 삽입 위치를 보정해야 드래그 방향과 무관하게 target 앞에 놓인다.
                let destination =
                    from < self.currentIndex ? self.currentIndex - 1 : self.currentIndex
                let site = self.sites.remove(at: from)
                self.sites.insert(site, at: destination)
                self.selectedIndex = destination
                self.onDrop()
            }
        }
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        true
    }
}

// MARK: - Pill Picker

struct PillPickerItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            }
            .foregroundColor(isActive ? .white : DS.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isActive
                    ? DS.accent
                    : (isHovered ? DS.border.opacity(0.4) : Color.clear)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

struct PillPicker: View {
    @Binding var selection: LaunchType

    private let items: [(LaunchType, String, String)] = [
        (.url, "bolt.fill", "URL"),
        (.app, "app.fill", "App"),
        (.finder, "folder.fill", "Finder"),
        (.shell, "terminal.fill", "Shell"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { item in
                PillPickerItem(
                    icon: item.1,
                    label: item.2,
                    isActive: selection == item.0,
                    action: { selection = item.0 }
                )
            }
        }
        .padding(4)
        .background(DS.border.opacity(0.2))
        .clipShape(Capsule())
    }
}

// MARK: - Minimap

struct MinimapSwiftUI: View {
    /// 실행 대상 디스플레이 식별. 둘 다 nil이면 Follow Cursor.
    let selectedIdentifier: String?
    let selectedName: String?
    /// Follow Cursor 상태에서 size/preset을 편집 중인 디스플레이.
    let focusedIdentifier: String?
    let focusedName: String?
    let previewSizeForScreen: (NSScreen) -> (width: Int, height: Int)
    let previewLabelForScreen: (NSScreen) -> String
    /// Follow Cursor 상태에서 preview 클릭 시 size/preset 편집 화면만 바꾼다.
    let onPreviewSelect: (NSScreen) -> Void

    private var isFollowingCursor: Bool {
        selectedIdentifier == nil && selectedName == nil
    }

    /// 화면이 현재 선택 상태인지. Follow Cursor(둘 다 nil)면 전체 하이라이트.
    /// UUID 우선 매칭으로 동일 모델 모니터도 정확히 구분한다.
    private func isSelected(_ screen: NSScreen) -> Bool {
        if selectedIdentifier == nil, selectedName == nil { return true }
        if let id = selectedIdentifier { return displayUUID(for: screen) == id }
        return screen.localizedName == selectedName
    }

    private func isFocused(_ screen: NSScreen) -> Bool {
        if let id = focusedIdentifier {
            return displayUUID(for: screen) == id
        }
        if let name = focusedName {
            return screen.localizedName == name
        }
        return false
    }

    /// 미리보기 창을 그릴 대상 화면(식별자 → 이름 → 커서 화면).
    private func previewScreen(_ screens: [NSScreen]) -> NSScreen? {
        if let id = selectedIdentifier,
            let screen = screens.first(where: { displayUUID(for: $0) == id })
        {
            return screen
        }
        if let name = selectedName,
            let screen = screens.first(where: { $0.localizedName == name })
        {
            return screen
        }
        // Follow Cursor mode: target the cursor screen
        return cursorScreen ?? NSScreen.main ?? screens.first
    }

    private func previewScreens(_ screens: [NSScreen]) -> [NSScreen] {
        if isFollowingCursor {
            return screens
        }
        return previewScreen(screens).map { [$0] } ?? []
    }

    var body: some View {
        GeometryReader { geo in
            let screens = NSScreen.screens
            let allFrames = screens.map { $0.frame }
            let minX = allFrames.map { $0.minX }.min() ?? 0
            let minY = allFrames.map { $0.minY }.min() ?? 0
            let maxX = allFrames.map { $0.maxX }.max() ?? 1512
            let maxY = allFrames.map { $0.maxY }.max() ?? 982
            let totalW = maxX - minX
            let totalH = maxY - minY

            let scale = min(geo.size.width / totalW, geo.size.height / totalH)
            let mapW = totalW * scale
            let mapH = totalH * scale
            let offsetX = (geo.size.width - mapW) / 2
            let offsetY = (geo.size.height - mapH) / 2

            ZStack(alignment: .topLeading) {
                ForEach(0..<screens.count, id: \.self) { i in
                    let frame = screens[i].frame
                    let sx = (frame.origin.x - minX) * scale
                    let sy = (maxY - frame.origin.y - frame.height) * scale
                    let selected = isSelected(screens[i])
                    let focused = isFollowingCursor && isFocused(screens[i])

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            focused
                                ? DS.accent.opacity(0.16)
                                : (selected ? DS.accent.opacity(0.08) : DS.cardBg)
                        )
                        .frame(width: frame.width * scale, height: frame.height * scale)
                        .overlay(
                            VStack(spacing: 2) {
                                Text(screens[i].localizedName)
                                    .font(.system(size: 8))
                                    .foregroundColor(
                                        selected || focused ? DS.accent : DS.textTertiary)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4).stroke(
                                selected || focused ? DS.accent : DS.border,
                                lineWidth: focused ? 2 : 1
                            )
                        )
                        .offset(x: offsetX + sx, y: offsetY + sy)
                        .onTapGesture {
                            guard isFollowingCursor else { return }
                            onPreviewSelect(screens[i])
                        }
                }

                ForEach(previewScreens(screens), id: \.self) { targetScreen in
                    let previewSize = previewSizeForScreen(targetScreen)
                    let previewLabel = previewLabelForScreen(targetScreen)
                    let visibleFrame = targetScreen.visibleFrame
                    let visibleLocalX = (visibleFrame.origin.x - minX) * scale
                    let visibleLocalY = (maxY - visibleFrame.origin.y - visibleFrame.height) * scale

                    let winX =
                        visibleLocalX
                        + (visibleFrame.width * scale - CGFloat(previewSize.width) * scale) / 2
                    let winY =
                        visibleLocalY
                        + (visibleFrame.height * scale - CGFloat(previewSize.height) * scale) / 2

                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.accent.opacity(0.25))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(DS.accent))
                        .overlay(alignment: .topLeading) {
                            Text(previewLabel)
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(DS.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(2)
                        }
                        .frame(
                            width: CGFloat(previewSize.width) * scale,
                            height: CGFloat(previewSize.height) * scale
                        )
                        .offset(x: offsetX + winX, y: offsetY + winY)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
