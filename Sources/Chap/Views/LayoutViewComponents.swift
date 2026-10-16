import AppKit
import SwiftUI

// Layout 캡처 창과 설정창 Layouts 섹션이 함께 쓰는 작은 뷰들.

/// 화면 안에서 창이 놓인 자리를 보여 주는 미니맵.
/// 창 사각형은 틀 안쪽 여백 안에만 그려, 화면 끝에 붙은 창이어도 틀 테두리와 겹치지 않는다.
struct LayoutFramePreview: View {
    let frame: LayoutFrame

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

/// 캡슐 모양 디스플레이 선택 버튼. 누르거나(키보드: Space·Return) 버튼 바로 아래에 NSMenu를 띄운다.
/// SwiftUI Menu는 macOS에서 버튼 bezel을 남겨 캡슐 양옆에 자국이 생기므로 쓰지 않는다.
struct LayoutDisplayMenuButton: View {
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
    @FocusState private var isFocused: Bool

    /// 캡슐 대신 반지름이 높이의 절반보다 조금 작은 연속 모서리. Capsule의 strokeBorder는
    /// 양 끝 꼭짓점에서 선이 한 픽셀 튀어나와 세로 자국처럼 보인다.
    private static let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)

    var body: some View {
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
        .foregroundColor(isHovered || isFocused ? DS.textPrimary : DS.textSecondary)
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Self.shape.fill(DS.surfaceBg.opacity(isHovered ? 1 : 0.9)))
        .overlay(Self.shape.strokeBorder(isFocused ? DS.accent : DS.border, lineWidth: 1))
        .contentShape(Self.shape)
        .frame(maxWidth: 200, alignment: .trailing)
        .fixedSize()
        // 메뉴는 버튼 아래에 붙여 띄운다. 좌표는 AppKit 뷰로 읽는다.
        .background(MenuAnchor(anchor: anchorView))
        .onTapGesture { showMenu() }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.space) {
            showMenu()
            return .handled
        }
        .onKeyPress(.return) {
            showMenu()
            return .handled
        }
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showMenu() }
    }

    @State private var anchorView = AnchorBox()

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
        if let view = anchorView.view {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }
}

/// 버튼의 AppKit 뷰를 붙잡아 메뉴를 그 아래에 띄울 수 있게 한다.
private final class AnchorBox {
    weak var view: NSView?
}

private struct MenuAnchor: NSViewRepresentable {
    let anchor: AnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
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

/// Layout 전체 배치 미리보기. 창이 놓일 디스플레이마다 화면 하나를 그리고, 그 위에 창 사각형과
/// 앱 이름을 올린다. Follow Cursor 창은 "Follow Cursor" 화면에 모은다. 고른 창은 진하게 강조한다.
struct LayoutPreviewByDisplay: View {
    let windows: [LayoutWindow]
    /// 연결된 디스플레이 이름을 메뉴와 같게 붙이려고 받는다.
    let displays: [LayoutDisplay]
    var highlightedID: UUID?

    private struct Screen: Identifiable {
        let id: String
        let title: String
        let windows: [LayoutWindow]
    }

    private var screens: [Screen] {
        var order: [String] = []
        var grouped: [String: [LayoutWindow]] = [:]
        var titles: [String: String] = [:]
        for window in windows {
            let key = window.display.map { $0.identifier ?? "name:\($0.name)" } ?? "cursor"
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(window)
            if titles[key] == nil {
                titles[key] = LayoutDisplay.label(for: window.display, among: displays)
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

extension LayoutDisplayMenuButton {
    /// 창 하나의 디스플레이 선택지: 연결된 디스플레이들, (연결되지 않은 저장 디스플레이), Follow Cursor.
    /// 캡처 창과 설정 화면이 같은 메뉴를 쓴다.
    static func displayChoices(
        for window: LayoutWindow, among connected: [LayoutDisplay],
        move: @escaping (LayoutDisplay?) -> Void
    ) -> [Choice] {
        let labels = LayoutDisplay.menuLabels(for: connected)
        var choices = connected.enumerated().map { index, display in
            Choice(
                title: labels[index],
                isSelected: window.display.map { $0.matches(display) } ?? false
            ) { move(display) }
        }
        if let saved = window.display, !connected.contains(where: { $0.matches(saved) }) {
            choices.append(
                Choice(
                    title: LayoutDisplay.label(for: saved, among: connected), isSelected: true,
                    startsSection: true, action: {}))
        }
        choices.append(
            Choice(title: "Follow Cursor", isSelected: window.display == nil, startsSection: true) {
                move(nil)
            })
        return choices
    }
}
