import SwiftUI

/// 설정창이 Layout에 대해 앱에 부탁하는 일. 실제 동작(권한·창 제어·확인 창)은 AppDelegate가 맡는다.
struct LayoutSettingsActions {
    var open: (UUID) -> Void = { _ in }
    var capture: () -> Void = {}
    var updatePositions: (UUID) -> Void = { _ in }
    var remove: (UUID) -> Void = { _ in }
}

/// Launchers 탭에서 Layout 하나를 고치는 화면. 바꾸는 즉시 저장한다(이름은 Enter나 칸을 벗어날 때).
/// - 위: 이름, Open, Update Positions(지금 창 위치로), 삭제
/// - 가운데: 디스플레이별 배치 미리보기
/// - 아래: 창 목록. 창마다 디스플레이를 바꾸거나 Layout에서 뺀다.
struct LayoutDetailView: View {
    @ObservedObject var library: LayoutLibrary
    let layoutID: UUID
    let displays: [LayoutDisplay]
    let actions: LayoutSettingsActions

    @State private var nameDraft = ""
    @State private var hoveredWindowID: UUID?
    @FocusState private var nameFocused: Bool

    private var layout: ChapLayout? { library.layout(id: layoutID) }
    private var isBusy: Bool { library.busyID == layoutID }

    var body: some View {
        if let layout {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.spacing) {
                    header(layout)
                    previewCard(layout)
                    windowsCard(layout)
                    Text("App names, window titles, and positions stay on this Mac.")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.leading, DS.paddingSmall)
                .padding(.trailing, DS.padding)
                .padding(.vertical, DS.paddingSmall)
            }
            .onAppear { nameDraft = layout.name }
            .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
            .onDisappear(perform: commitName)
        }
    }

    // MARK: - Header

    private func header(_ layout: ChapLayout) -> some View {
        CardSection {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    TextField("Layout name", text: $nameDraft)
                        .textFieldStyle(.plain)
                        .font(DS.bodyFont)
                        .padding(DS.paddingSmall)
                        .background(DS.surfaceBg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(nameFocused ? DS.accent : DS.border, lineWidth: 1)
                        )
                        .focused($nameFocused)
                        .onSubmit(commitName)
                        .accessibilityLabel("Layout name")
                }
                HStack(spacing: 8) {
                    Button {
                        actions.open(layout.id)
                    } label: {
                        Label("Open", systemImage: "play.fill")
                    }
                    .help("Open these apps and put their windows in place")
                    Button {
                        actions.updatePositions(layout.id)
                    } label: {
                        Label("Update Positions", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help("Save where these apps' windows are right now")
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Working")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        actions.remove(layout.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .help("Remove this layout. Apps and windows are not changed.")
                }
                .controlSize(.regular)
                .disabled(library.busyID != nil)
            }
        }
    }

    // MARK: - Preview

    private func previewCard(_ layout: ChapLayout) -> some View {
        CardSection {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preview")
                    .font(DS.captionFont.weight(.semibold))
                    .foregroundColor(DS.textSecondary)
                LayoutPreviewByDisplay(
                    windows: layout.windows, displays: displays,
                    highlightedID: hoveredWindowID)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Windows

    private func windowsCard(_ layout: ChapLayout) -> some View {
        CardSection {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Windows")
                        .font(DS.captionFont.weight(.semibold))
                        .foregroundColor(DS.textSecondary)
                    Text("\(layout.windows.count)/\(LayoutStore.maxWindows)")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                        .monospacedDigit()
                    Spacer()
                }
                ForEach(layout.windows) { window in
                    windowRow(window, in: layout)
                }
                Text(
                    "Update Positions saves where these apps' windows are now. To add an app, capture a new layout."
                )
                .font(DS.captionFont)
                .foregroundColor(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func windowRow(_ window: LayoutWindow, in layout: ChapLayout) -> some View {
        let isLast = layout.windows.count == 1
        return HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: window.applicationPath))
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(window.applicationName)
                    .font(DS.bodyFont.weight(.medium))
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)
                if let title = window.windowTitle, !title.isEmpty {
                    Text(title)
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            LayoutDisplayMenuButton(
                title: displayLabel(for: window),
                symbol: window.display == nil ? "cursorarrow" : "display",
                choices: LayoutDisplayMenuButton.displayChoices(
                    for: window, among: displays
                ) { move(window, to: $0, in: layout) }
            )
            .help("Display this window opens on")
            .accessibilityLabel("Display for \(window.applicationName)")
            .accessibilityValue(displayLabel(for: window))
            // 자리는 위 Preview가 보여 준다(줄에 마우스를 올리면 그 창이 진해진다).
            Button {
                save(layout, windows: layout.windows.filter { $0.id != window.id })
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isLast ? DS.textTertiary.opacity(0.5) : DS.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(isLast)
            .help(
                isLast
                    ? "A layout needs at least one window. Delete the layout instead."
                    : "Leave this window out"
            )
            .accessibilityLabel("Leave out \(window.applicationName)")
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                .fill(hoveredWindowID == window.id ? DS.accentSoft : DS.surfaceBg)
        )
        .onHover { inside in
            if inside {
                hoveredWindowID = window.id
            } else if hoveredWindowID == window.id {
                hoveredWindowID = nil
            }
        }
    }

    // MARK: - Displays

    private func displayLabel(for window: LayoutWindow) -> String {
        LayoutDisplay.label(for: window.display, among: displays)
    }

    // MARK: - Saving

    private func move(
        _ window: LayoutWindow, to display: LayoutDisplay?, in layout: ChapLayout
    ) {
        save(
            layout,
            windows: layout.windows.map { $0.id == window.id ? $0.assigned(to: display) : $0 })
    }

    private func save(_ layout: ChapLayout, windows: [LayoutWindow]) {
        library.replace(layout.id, name: layout.name, windows: windows)
    }

    private func commitName() {
        guard let layout else { return }
        guard let cleaned = LayoutStore.cleanedName(nameDraft) else {
            // 비운 이름은 저장하지 않고 원래 이름으로 돌린다.
            nameDraft = layout.name
            return
        }
        nameDraft = cleaned
        guard cleaned != layout.name else { return }
        library.replace(layout.id, name: cleaned, windows: layout.windows)
    }
}
