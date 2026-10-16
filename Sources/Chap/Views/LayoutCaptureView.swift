import SwiftUI

struct LayoutCaptureView: View {
    @ObservedObject var model: LayoutCaptureViewModel
    let onCancel: () -> Void
    let onSave: (String, [LayoutWindow]) -> Void

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
        // 창을 열어 둔 채 모니터를 꽂거나 뽑으면 디스플레이 메뉴도 따라간다.
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            model.displays = LayoutDisplay.connected()
        }
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
                Text("Capture Layout")
                    .font(DS.headlineFont)
                    .foregroundColor(DS.textPrimary)
                Text("Saves app names, window titles, and positions. Stays on this Mac.")
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
                Text("Open an app window that isn't minimized or full screen, then try again.")
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
    private func candidateRow(_ window: LayoutWindow) -> some View {
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
            LayoutFramePreview(frame: window.frame)
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
        .opacity(selected || !model.isAtSelectionLimit ? 1 : 0.55)
        .onTapGesture { model.toggle(window.id) }
        // 키보드: 줄에 포커스를 두고 Space로 고르고 뺀다.
        .focusable()
        .onKeyPress(.space) {
            model.toggle(window.id)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(window.applicationName), \(displayLabel(for: window))")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.toggle(window.id) }
    }

    /// 이 창을 띄울 디스플레이. 바꿔도 화면 안의 상대 위치·크기는 그대로다.
    private func displayMenu(for window: LayoutWindow) -> some View {
        LayoutDisplayMenuButton(
            title: displayLabel(for: window),
            symbol: window.display == nil ? "cursorarrow" : "display",
            choices: LayoutDisplayMenuButton.displayChoices(
                for: window, among: model.displays
            ) { model.setDisplay($0, for: window.id) }
        )
        .help("Display this window opens on")
        .accessibilityLabel("Display for \(window.applicationName)")
        .accessibilityValue(displayLabel(for: window))
    }

    private func displayLabel(for window: LayoutWindow) -> String {
        LayoutDisplay.label(for: window.display, among: model.displays)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Name")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                TextField("Deep Work", text: $model.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Layout name")
            }
            HStack {
                Text(
                    model.isAtSelectionLimit
                        ? "\(model.selectedWindows.count) selected · up to \(LayoutStore.maxWindows)"
                        : "\(model.selectedWindows.count) selected"
                )
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
    private func detailText(for window: LayoutWindow) -> String {
        let title = window.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !model.offersDisplayChoice else { return title.isEmpty ? " " : title }
        let display = displayLabel(for: window)
        return title.isEmpty ? display : "\(display) · \(title)"
    }
}
