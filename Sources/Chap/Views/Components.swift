import Cocoa
import SwiftUI

// MARK: - Sidebar Item

struct SidebarItem: View {
    let icon: String
    let name: String
    let subtitle: String?
    let badge: String?
    let isSelected: Bool
    @State private var isHovered = false

    init(
        icon: String, name: String, subtitle: String? = nil, badge: String? = nil,
        isSelected: Bool = false
    ) {
        self.icon = icon
        self.name = name
        self.subtitle = subtitle
        self.badge = badge
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? DS.accent : DS.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(DS.bodyFont)
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(DS.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(DS.border.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.plainText]).first else { return false }
        item.loadObject(ofClass: String.self) { str, _ in
            guard let str = str, let from = Int(str) else { return }
            DispatchQueue.main.async {
                if from != currentIndex {
                    let site = sites.remove(at: from)
                    sites.insert(site, at: currentIndex)
                    selectedIndex = currentIndex
                    onDrop()
                }
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
    let width: Int
    let height: Int
    var displayName: String? = nil

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

                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.cardBg)
                        .frame(width: frame.width * scale, height: frame.height * scale)
                        .overlay(
                            VStack {
                                Text(screens[i].localizedName)
                                    .font(.system(size: 8))
                                    .foregroundColor(DS.textTertiary)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4).stroke(
                                displayName == nil || screens[i].localizedName == displayName
                                    ? DS.accent : DS.border
                            )
                        )
                        .offset(x: offsetX + sx, y: offsetY + sy)
                }

                let targetScreen =
                    displayName.flatMap { name in screens.first { $0.localizedName == name } }
                    ?? NSScreen.main ?? screens.first!
                let tFrame = targetScreen.frame
                let screenLocalX = (tFrame.origin.x - minX) * scale
                let screenLocalY = (maxY - tFrame.origin.y - tFrame.height) * scale

                let winX = screenLocalX + (tFrame.width * scale - CGFloat(width) * scale) / 2
                let winY = screenLocalY + (tFrame.height * scale - CGFloat(height) * scale) / 2

                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.accent.opacity(0.25))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(DS.accent))
                    .frame(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
                    .offset(x: offsetX + winX, y: offsetY + winY)
            }
        }
    }
}
