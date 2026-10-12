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

// MARK: - Sidebar Add Row

/// 비어 있는 타입 섹션에 표시되는 placeholder 행.
/// 항목이 하나도 없는 타입(예: Finder)도 사이드바에서 바로 추가할 수 있게 한다.
struct SidebarAddRow: View {
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundColor(DS.textTertiary)
                    .frame(width: 20)
                Text(label)
                    .font(DS.bodyFont)
                    .foregroundColor(DS.textTertiary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, DS.paddingSmall)
            .padding(.vertical, 8)
            .background(isHovered ? DS.border.opacity(0.3) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
        }
        .buttonStyle(.plain)
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
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isActive ? .white : DS.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isActive
                    ? DS.accent
                    : (isHovered ? DS.border.opacity(0.4) : Color.clear)
            )
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

struct PillPicker: View {
    @Binding var selection: LaunchType

    private let barWidth: CGFloat = 420
    private let items: [(LaunchType, String, String)] = [
        (.url, LauncherListPolicy.symbolName(for: .url), "URL"),
        (.app, "app.fill", "App"),
        (.finder, "folder.fill", "Finder"),
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
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text("Soon")
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(DS.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .help("Coming soon")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Coming soon")
        }
        .padding(4)
        .frame(width: barWidth)
        .background(DS.border.opacity(0.2))
        .clipShape(Capsule())
    }
}

// MARK: - Minimap

struct MinimapSwiftUI: View {
    /// 실행 대상 디스플레이 식별. 둘 다 nil이면 Follow Cursor.
    let selectedIdentifier: String?
    let selectedName: String?
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

    private func matchingScreen(
        identifier: String?,
        name: String?,
        in screens: [NSScreen]
    ) -> NSScreen? {
        if let identifier,
            let screen = screens.first(where: { displayUUID(for: $0) == identifier })
        {
            return screen
        }
        if let name {
            return screens.first(where: { $0.localizedName == name })
        }
        return nil
    }

    /// Detail preview 대상. 명시적으로 선택한 display가 있으면 그것을, 아니면 현재 cursor screen을 표시한다.
    private func previewScreen(_ screens: [NSScreen]) -> NSScreen? {
        if let selected = matchingScreen(
            identifier: selectedIdentifier,
            name: selectedName,
            in: screens
        ) {
            return selected
        }
        if isFollowingCursor,
            let focused = matchingScreen(
                identifier: focusedIdentifier,
                name: focusedName,
                in: screens
            )
        {
            return focused
        }
        return cursorScreen ?? NSScreen.main ?? screens.first
    }

    private func overview(_ screens: [NSScreen]) -> some View {
        GeometryReader { geo in
            let allFrames = screens.map(\.frame)
            let minX = allFrames.map(\.minX).min() ?? 0
            let minY = allFrames.map(\.minY).min() ?? 0
            let maxX = allFrames.map(\.maxX).max() ?? 1
            let maxY = allFrames.map(\.maxY).max() ?? 1
            let totalWidth = max(maxX - minX, 1)
            let totalHeight = max(maxY - minY, 1)
            let padding: CGFloat = 8
            let availableWidth = max(geo.size.width - padding * 2, 1)
            let availableHeight = max(geo.size.height - padding * 2, 1)
            let scale = min(availableWidth / totalWidth, availableHeight / totalHeight)
            let mapWidth = totalWidth * scale
            let mapHeight = totalHeight * scale
            let offsetX = (geo.size.width - mapWidth) / 2
            let offsetY = (geo.size.height - mapHeight) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                    let frame = screen.frame
                    let renderedSize = CGSize(
                        width: frame.width * scale,
                        height: frame.height * scale
                    )
                    let x = (frame.minX - minX) * scale
                    let y = (maxY - frame.minY - frame.height) * scale
                    let selected = isSelected(screen)
                    let focused = isFollowingCursor && isFocused(screen)
                    let label = DisplayPreviewPolicy.overviewLabel(
                        displayName: screen.localizedName,
                        displayIndex: index,
                        renderedSize: renderedSize
                    )
                    let usesBadge = label != screen.localizedName

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            focused
                                ? DS.accent.opacity(0.16)
                                : (selected ? DS.accent.opacity(0.08) : DS.cardBg)
                        )
                        .frame(width: renderedSize.width, height: renderedSize.height)
                        .overlay {
                            if usesBadge {
                                Text(label)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(selected ? DS.accent : DS.textSecondary)
                                    .frame(width: 16, height: 16)
                                    .background(DS.surfaceBg.opacity(0.9))
                                    .clipShape(Circle())
                            } else {
                                Text(label)
                                    .font(.system(size: 8))
                                    .foregroundColor(selected ? DS.accent : DS.textTertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(3)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 4).stroke(
                                selected ? DS.accent : DS.border,
                                lineWidth: 1
                            )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                        .offset(x: offsetX + x, y: offsetY + y)
                        .accessibilityLabel("Display \(index + 1): \(screen.localizedName)")
                        .onTapGesture {
                            onPreviewSelect(screen)
                        }
                }
            }
        }
        .clipped()
        .background(DS.surfaceBg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.border, lineWidth: 1))
    }

    private func topologyPane(_ screens: [NSScreen]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("All Displays")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                if isFollowingCursor {
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(DS.accent)
                }
            }
            overview(screens)
                .frame(
                    minHeight: DisplayPreviewPolicy.topologyHeight,
                    maxHeight: .infinity
                )
        }
        .padding(6)
        .frame(width: 156, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .leading)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityHint(
            isFollowingCursor ? "Click a display to configure it" : "Click a display to select it"
        )
    }

    private func compactTopologyPane(_ screens: [NSScreen]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("All Displays")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                if isFollowingCursor {
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(DS.accent)
                }
            }
            overview(screens)
                .frame(height: DisplayPreviewPolicy.compactTopologyHeight)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityHint(
            isFollowingCursor ? "Click a display to configure it" : "Click a display to select it"
        )
    }

    private func detailCanvas(for screen: NSScreen) -> some View {
        GeometryReader { geo in
            let visibleFrame = screen.visibleFrame
            let displaySize = DisplayPreviewPolicy.detailDisplaySize(
                displaySize: visibleFrame.size,
                availableSize: geo.size
            )
            let displayScale = min(
                displaySize.width / max(visibleFrame.width, 1),
                displaySize.height / max(visibleFrame.height, 1)
            )
            let requestedWindowSize = previewSizeForScreen(screen)
            let windowSize = CGSize(
                width: min(
                    CGFloat(requestedWindowSize.width) * displayScale,
                    displaySize.width - 4
                ),
                height: min(
                    CGFloat(requestedWindowSize.height) * displayScale,
                    displaySize.height - 4
                )
            )
            let windowLabel = previewLabelForScreen(screen)

            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(DS.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7).stroke(DS.accent, lineWidth: 1.5)
                    )
                    .frame(width: displaySize.width, height: displaySize.height)
                    .overlay(alignment: .topLeading) {
                        Text(screen.localizedName)
                            .font(.system(size: 8))
                            .foregroundColor(DS.accent)
                            .lineLimit(1)
                            .padding(5)
                    }

                RoundedRectangle(cornerRadius: 3)
                    .fill(DS.accent.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3).stroke(DS.accent, lineWidth: 1.25)
                    )
                    .frame(width: windowSize.width, height: windowSize.height)
                    .overlay {
                        if windowSize.width >= 54, windowSize.height >= 28 {
                            Text(windowLabel)
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(DS.accent)
                                .lineLimit(1)
                                .padding(3)
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(
                "\(screen.localizedName) detail preview with \(windowLabel) window centered"
            )
        }
        .frame(maxWidth: .infinity)
        .background(DS.surfaceBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.border, lineWidth: 1))
    }

    @ViewBuilder
    private func previewPanes(for screen: NSScreen, screens: [NSScreen]) -> some View {
        if screens.count <= 1 {
            detailCanvas(for: screen)
                .frame(height: DisplayPreviewPolicy.detailHeight - 21)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DS.paddingSmall) {
                    detailCanvas(for: screen)
                    topologyPane(screens)
                }
                .frame(
                    minWidth: DisplayPreviewPolicy.splitPreviewMinimumWidth,
                    alignment: .leading
                )
                .frame(height: DisplayPreviewPolicy.detailHeight - 21)

                VStack(alignment: .leading, spacing: DS.paddingSmall) {
                    detailCanvas(for: screen)
                        .frame(height: DisplayPreviewPolicy.detailHeight - 21)
                    compactTopologyPane(screens)
                }
            }
        }
    }

    private func detailPreview(for screen: NSScreen, screens: [NSScreen]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(isFollowingCursor ? "Focused Display" : "Selected Display")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                Spacer()
                Text(screen.localizedName)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textTertiary)
                    .lineLimit(1)
            }

            previewPanes(for: screen, screens: screens)
        }
    }

    var body: some View {
        let screens = NSScreen.screens

        Group {
            if let screen = previewScreen(screens) {
                detailPreview(for: screen, screens: screens)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// "⌥ [키]" 입력. 새로 친 글자 하나로 바뀌고, 비우면 끈다(prompt "Off").
struct OptionKeyField: View {
    @Binding var key: String?
    var accessibilityLabel: String

    var body: some View {
        HStack(spacing: 4) {
            Text("⌥")
                .foregroundColor(DS.textSecondary)
            TextField(
                "",
                text: Binding(
                    get: { key ?? "" },
                    set: { newValue in
                        // 마지막에 친 글자로 바꾼다(칸에 한 글자만 남는다). 비우면 끈다.
                        key = QuickNoteShortcutPolicy.normalized(newValue.last.map(String.init))
                    }),
                prompt: Text("Off")
            )
            .keyCapField(width: 40)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}

extension View {
    /// 한 글자 키 입력 칸. `.roundedBorder`는 Form 줄 안에서 아래로 밀려 줄을 두 배로 키우므로,
    /// 평범한 칸에 상자를 직접 그린다 (높이가 글자 줄과 같아 한 줄에 맞는다).
    func keyCapField(width: CGFloat) -> some View {
        textFieldStyle(.plain)
            // Form 안의 TextField는 빈 제목이라도 제목 자리를 잡아 글자를 아래로 민다. 제목을 숨긴다.
            .labelsHidden()
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
            // 높이를 고정한다. 두 줄짜리 제목 옆에 놓이면 칸이 줄 높이만큼 늘어난다.
            .frame(width: width, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

// MARK: - Settings page building blocks

/// General·Notch·Tools 탭이 함께 쓰는 페이지 틀: 가운데 정렬된 grouped Form(최대 560pt).
struct SettingsFormPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Form { content() }
                .formStyle(.grouped)
                .frame(maxWidth: 560)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.surfaceBg)
    }
}

/// 섹션 제목: 아이콘 + 이름, 그 아래 한 줄 설명. 설명은 섹션당 하나만 둔다.
struct SettingsSectionHeader: View {
    let title: String
    var systemImage: String?
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(title)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage).foregroundColor(DS.accent)
                }
            }
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(DS.textSecondary)
                    .textCase(nil)
            }
        }
    }
}

/// 설정 한 줄: 왼쪽에 제목과 한 줄 설명(겹침 안내가 있으면 그것으로 대체), 오른쪽에 컨트롤.
/// 모든 탭이 같은 줄 모양을 써서 설정이 늘어도 한눈에 읽힌다. 긴 설명은 툴팁(`help`)으로 보낸다.
struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String?
    /// 단축키가 사이트·다른 기능과 겹칠 때. 있으면 설명 자리에 빨간 글씨로 대신 뜬다.
    var conflictMessage: String?
    var help: String?
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let conflictMessage {
                    Label(conflictMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(DS.danger)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(conflictMessage)
                } else if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(DS.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .help(help ?? "")
    }
}

/// 켜고 끄는 설정 한 줄 (`SettingsRow` + 스위치).
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    var help: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, help: help) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
