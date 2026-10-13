import AppKit
import SwiftUI

// Workspace 캡처 창과 설정창 Workspaces 섹션이 함께 쓰는 작은 뷰들.

/// 화면 안에서 창이 놓인 자리를 보여 주는 미니맵.
/// 창 사각형은 틀 안쪽 여백 안에만 그려, 화면 끝에 붙은 창이어도 틀 테두리와 겹치지 않는다.
struct WorkspaceFramePreview: View {
    let frame: WorkspaceFrame

    private static let size = CGSize(width: 54, height: 34)
    /// 틀 테두리와 창 사각형 사이의 여백.
    private static let inset: CGFloat = 3
    private static let minimumWindowSize = CGSize(width: 5, height: 4)

    var body: some View {
        GeometryReader { geometry in
            let canvas = geometry.size
            let width = min(
                max(canvas.width * frame.width, Self.minimumWindowSize.width), canvas.width)
            let height = min(
                max(canvas.height * frame.height, Self.minimumWindowSize.height), canvas.height)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DS.accent.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(DS.accent, lineWidth: 1)
                )
                .frame(width: width, height: height)
                // 최소 크기로 커진 사각형도 틀 밖으로 밀려나지 않게 자리를 맞춘다.
                .offset(
                    x: min(canvas.width * frame.left, canvas.width - width),
                    y: min(canvas.height * frame.top, canvas.height - height))
        }
        .padding(Self.inset)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(DS.border.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(DS.border, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

/// 캡슐 모양 디스플레이 선택 버튼. 누르면 커서 자리에 기본 NSMenu를 띄운다.
/// SwiftUI Menu는 macOS에서 버튼 bezel을 남겨 캡슐 양옆에 자국이 생기므로 쓰지 않는다.
struct WorkspaceDisplayMenuButton: View {
    struct Choice {
        let title: String
        let isSelected: Bool
        var startsSection = false
        let action: () -> Void
    }

    let title: String
    let symbol: String
    let choices: [Choice]
    @State private var isHovered = false

    /// 캡슐 대신 반지름이 높이의 절반보다 조금 작은 연속 모서리. Capsule의 strokeBorder는
    /// 양 끝 꼭짓점에서 선이 한 픽셀 튀어나와 세로 자국처럼 보인다.
    private static let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)

    var body: some View {
        // Button 대신 탭 제스처: ToolbarIconButton과 같이 첫 클릭에 바로 반응하고,
        // 오프스크린 렌더에서 버튼 bezel 자국이 캡슐 양옆에 남지 않는다.
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .medium))
            Text(title)
                .font(DS.captionFont)
                .lineLimit(1)
                .truncationMode(.tail)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundColor(isHovered ? DS.textPrimary : DS.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Self.shape.fill(DS.surfaceBg.opacity(isHovered ? 1 : 0.9)))
        .overlay(Self.shape.strokeBorder(DS.border, lineWidth: 1))
        .contentShape(Self.shape)
        .frame(maxWidth: 200, alignment: .trailing)
        .fixedSize()
        .onTapGesture(perform: showMenu)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showMenu() }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let handler = MenuActionHandler(actions: choices.map(\.action))
        for (index, choice) in choices.enumerated() {
            if choice.startsSection { menu.addItem(.separator()) }
            let item = NSMenuItem(
                title: choice.title, action: #selector(MenuActionHandler.perform(_:)),
                keyEquivalent: "")
            item.tag = index
            item.target = handler
            item.state = choice.isSelected ? .on : .off
            menu.addItem(item)
        }
        // NSMenuItem.target는 약한 참조라 메뉴가 떠 있는 동안 핸들러를 붙잡아 둔다.
        objc_setAssociatedObject(menu, &MenuActionHandler.key, handler, .OBJC_ASSOCIATION_RETAIN)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

private final class MenuActionHandler: NSObject {
    nonisolated(unsafe) static var key: UInt8 = 0
    private let actions: [() -> Void]

    init(actions: [() -> Void]) {
        self.actions = actions
    }

    @objc func perform(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}

/// Workspace 전체 배치 미리보기. 창이 놓일 디스플레이마다 화면 하나를 그리고, 그 위에 창 사각형과
/// 앱 이름을 올린다. Follow Cursor 창은 "Follow Cursor" 화면에 모은다. 고른 창은 진하게 강조한다.
struct WorkspaceLayoutPreview: View {
    let windows: [WorkspaceWindow]
    /// 연결된 디스플레이 이름을 메뉴와 같게 붙이려고 받는다.
    let displays: [WorkspaceDisplay]
    var highlightedID: UUID?

    private struct Screen: Identifiable {
        let id: String
        let title: String
        let windows: [WorkspaceWindow]
    }

    private var screens: [Screen] {
        let labels = WorkspaceDisplay.menuLabels(for: displays)
        var order: [String] = []
        var grouped: [String: [WorkspaceWindow]] = [:]
        var titles: [String: String] = [:]
        for window in windows {
            let key = window.display.map { $0.identifier ?? "name:\($0.name)" } ?? "cursor"
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(window)
            if titles[key] == nil {
                if let display = window.display {
                    let index = displays.firstIndex { $0.identifier == display.identifier }
                    titles[key] = index.map { labels[$0] } ?? display.name
                } else {
                    titles[key] = "Follow Cursor"
                }
            }
        }
        return order.map { Screen(id: $0, title: titles[$0] ?? "", windows: grouped[$0] ?? []) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(screens) { screen in
                VStack(alignment: .leading, spacing: 5) {
                    Label(
                        screen.title, systemImage: screen.id == "cursor" ? "cursorarrow" : "display"
                    )
                    .font(.caption2.weight(.medium))
                    .foregroundColor(DS.textSecondary)
                    .lineLimit(1)
                    canvas(for: screen)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            screens.map {
                "\($0.title): \($0.windows.map(\.applicationName).joined(separator: ", "))"
            }
            .joined(separator: "; "))
    }

    private func canvas(for screen: Screen) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                ForEach(screen.windows) { window in
                    let highlighted = window.id == highlightedID
                    let width = max(size.width * window.frame.width, 14)
                    let height = max(size.height * window.frame.height, 10)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(DS.accent.opacity(highlighted ? 0.32 : 0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(
                                    DS.accent.opacity(highlighted ? 1 : 0.55),
                                    lineWidth: highlighted ? 1.5 : 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if width >= 40, height >= 16 {
                                Text(window.applicationName)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(DS.accent)
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 3)
                            }
                        }
                        .frame(width: width, height: height)
                        .offset(
                            x: min(size.width * window.frame.left, size.width - width),
                            y: min(size.height * window.frame.top, size.height - height))
                }
            }
        }
        .padding(4)
        .aspectRatio(16 / 10, contentMode: .fit)
        .frame(maxWidth: 240)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(DS.border.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(DS.border, lineWidth: 1))
    }
}
