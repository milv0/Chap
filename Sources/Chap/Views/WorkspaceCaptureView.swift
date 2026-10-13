import SwiftUI

struct WorkspaceCaptureView: View {
    @ObservedObject var model: WorkspaceCaptureViewModel
    /// 새로 캡처할 때와 저장된 Workspace를 고칠 때 같은 화면을 쓴다. 글자만 다르다.
    var title = "Capture Workspace"
    var subtitle = "Saves app names, window titles, and positions. Stays on this Mac."
    let onCancel: () -> Void
    let onSave: (String, [WorkspaceWindow]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 520, height: 500)
        .background(DS.surfaceBg)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DS.accent)
                .frame(width: 38, height: 38)
                .background(DS.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DS.headlineFont)
                    .foregroundColor(DS.textPrimary)
                Text(subtitle)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
            Spacer()
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("Looking at open windows…")
                    .font(DS.bodyFont)
                    .foregroundColor(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.candidates.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "macwindow.badge.xmark")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(DS.textTertiary)
                Text("No windows to capture")
                    .font(DS.headlineFont)
                    .foregroundColor(DS.textPrimary)
                Text("Arrange a standard app window, then try again.")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.candidates) { window in
                        candidateRow(window)
                    }
                }
                .padding(16)
            }
        }
    }

    /// 후보 한 줄. 줄을 누르면 고르고 빼며, 디스플레이 메뉴는 따로 눌리는 컨트롤이다
    /// (메뉴는 버튼 라벨 안에 넣으면 눌리지 않는다).
    private func candidateRow(_ window: WorkspaceWindow) -> some View {
        let selected = model.selectedIDs.contains(window.id)
        return HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: window.applicationPath))
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(window.applicationName)
                    .font(DS.bodyFont.weight(.medium))
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)
                Text(detailText(for: window))
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.offersDisplayChoice {
                displayMenu(for: window)
            }
            WorkspaceFramePreview(frame: window.frame)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(selected ? DS.accent : DS.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(selected ? DS.accentSoft : DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? DS.accent.opacity(0.35) : DS.border, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(window.id) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(window.applicationName), \(displayLabel(for: window)), "
                + (selected ? "selected" : "not selected")
        )
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.toggle(window.id) }
    }

    /// 이 창을 띄울 디스플레이. 바꿔도 화면 안의 상대 위치·크기는 그대로다.
    private func displayMenu(for window: WorkspaceWindow) -> some View {
        let labels = WorkspaceDisplay.menuLabels(for: model.displays)
        var choices = model.displays.enumerated().map { index, display in
            WorkspaceDisplayMenuButton.Choice(
                title: labels[index], isSelected: window.display?.identifier == display.identifier
            ) { model.setDisplay(display, for: window.id) }
        }
        choices.append(
            WorkspaceDisplayMenuButton.Choice(
                title: "Follow Cursor", isSelected: window.display == nil, startsSection: true
            ) { model.setDisplay(nil, for: window.id) })
        return WorkspaceDisplayMenuButton(
            title: displayLabel(for: window),
            symbol: window.display == nil ? "cursorarrow" : "display",
            choices: choices
        )
        .help("Display this window opens on")
        .accessibilityLabel("Display for \(window.applicationName)")
        .accessibilityValue(displayLabel(for: window))
    }

    /// 창의 디스플레이 이름. 같은 모델 모니터가 여럿이면 메뉴와 같은 번호를 붙인다.
    private func displayLabel(for window: WorkspaceWindow) -> String {
        guard let display = window.display else { return "Follow Cursor" }
        let labels = WorkspaceDisplay.menuLabels(for: model.displays)
        if let index = model.displays.firstIndex(where: { $0.identifier == display.identifier }) {
            return labels[index]
        }
        return display.name.isEmpty ? "Unknown display" : display.name
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Name")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                TextField("Deep Work", text: $model.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Workspace name")
            }
            HStack {
                Text("\(model.selectedWindows.count) selected")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(model.name, model.selectedWindows)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSave)
            }
        }
        .padding(16)
    }

    /// 둘째 줄: 창 제목. 디스플레이를 고를 수 없을 때(모니터 하나)는 디스플레이 이름을 앞에 붙인다.
    private func detailText(for window: WorkspaceWindow) -> String {
        let title = window.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !model.offersDisplayChoice else { return title.isEmpty ? " " : title }
        let display = displayLabel(for: window)
        return title.isEmpty ? display : "\(display) · \(title)"
    }
}

/// 화면 안에서 창이 놓인 자리를 보여 주는 미니맵.
/// 창 사각형은 틀 안쪽 여백 안에만 그려, 화면 끝에 붙은 창이어도 틀 테두리와 겹치지 않는다.
private struct WorkspaceFramePreview: View {
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
private struct WorkspaceDisplayMenuButton: View {
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
