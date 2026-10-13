import SwiftUI

/// 설정창이 Workspace에 대해 앱에 부탁하는 일. 실제 동작(권한·창 제어·확인 창)은 AppDelegate가 맡는다.
struct WorkspaceSettingsActions {
    var open: (UUID) -> Void = { _ in }
    var capture: () -> Void = {}
    var updatePositions: (UUID) -> Void = { _ in }
    var remove: (UUID) -> Void = { _ in }
}

/// Launchers 탭에서 Workspace 하나를 고치는 화면. 바꾸는 즉시 저장한다(이름은 Enter나 칸을 벗어날 때).
/// - 위: 이름, Open, Update Positions(지금 창 위치로), 삭제
/// - 가운데: 디스플레이별 배치 미리보기
/// - 아래: 창 목록. 창마다 디스플레이를 바꾸거나 Workspace에서 뺀다.
struct WorkspaceDetailView: View {
    @ObservedObject var library: WorkspaceLibrary
    let workspaceID: UUID
    let displays: [WorkspaceDisplay]
    let actions: WorkspaceSettingsActions

    @State private var nameDraft = ""
    @State private var hoveredWindowID: UUID?
    @FocusState private var nameFocused: Bool

    private var workspace: ChapWorkspace? { library.workspace(id: workspaceID) }
    private var isBusy: Bool { library.busyID == workspaceID }

    var body: some View {
        if let workspace {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.spacing) {
                    header(workspace)
                    layoutCard(workspace)
                    windowsCard(workspace)
                    Text("App names, window titles, and positions stay on this Mac.")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.leading, DS.paddingSmall)
                .padding(.trailing, DS.padding)
                .padding(.vertical, DS.paddingSmall)
            }
            .onAppear { nameDraft = workspace.name }
            .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
            .onDisappear(perform: commitName)
        }
    }

    // MARK: - Header

    private func header(_ workspace: ChapWorkspace) -> some View {
        CardSection {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    TextField("Workspace name", text: $nameDraft)
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
                        .accessibilityLabel("Workspace name")
                }
                HStack(spacing: 8) {
                    Button {
                        actions.open(workspace.id)
                    } label: {
                        Label("Open", systemImage: "play.fill")
                    }
                    .help("Open these apps and put their windows in place")
                    Button {
                        actions.updatePositions(workspace.id)
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
                        actions.remove(workspace.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .help("Remove this workspace. Apps and windows are not changed.")
                }
                .controlSize(.regular)
                .disabled(library.busyID != nil)
            }
        }
    }

    // MARK: - Layout

    private func layoutCard(_ workspace: ChapWorkspace) -> some View {
        CardSection {
            VStack(alignment: .leading, spacing: 10) {
                Text("Layout")
                    .font(DS.captionFont.weight(.semibold))
                    .foregroundColor(DS.textSecondary)
                WorkspaceLayoutPreview(
                    windows: workspace.windows, displays: displays,
                    highlightedID: hoveredWindowID)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Windows

    private func windowsCard(_ workspace: ChapWorkspace) -> some View {
        CardSection {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Windows")
                        .font(DS.captionFont.weight(.semibold))
                        .foregroundColor(DS.textSecondary)
                    Text("\(workspace.windows.count)/\(WorkspaceStore.maxWindows)")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                        .monospacedDigit()
                    Spacer()
                }
                ForEach(workspace.windows) { window in
                    windowRow(window, in: workspace)
                }
                Text(
                    "Update Positions saves where these apps' windows are now. To add an app, capture a new workspace."
                )
                .font(DS.captionFont)
                .foregroundColor(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func windowRow(_ window: WorkspaceWindow, in workspace: ChapWorkspace) -> some View {
        let isLast = workspace.windows.count == 1
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
            WorkspaceDisplayMenuButton(
                title: displayLabel(for: window),
                symbol: window.display == nil ? "cursorarrow" : "display",
                choices: WorkspaceDisplayMenuButton.displayChoices(
                    for: window, among: displays
                ) { move(window, to: $0, in: workspace) }
            )
            .help("Display this window opens on")
            .accessibilityLabel("Display for \(window.applicationName)")
            .accessibilityValue(displayLabel(for: window))
            // 자리는 위 Layout 미리보기가 보여 준다(줄에 마우스를 올리면 그 창이 진해진다).
            Button {
                save(workspace, windows: workspace.windows.filter { $0.id != window.id })
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isLast ? DS.textTertiary.opacity(0.5) : DS.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(isLast)
            .help(
                isLast
                    ? "A workspace needs at least one window. Delete the workspace instead."
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

    private func displayLabel(for window: WorkspaceWindow) -> String {
        WorkspaceDisplay.label(for: window.display, among: displays)
    }

    // MARK: - Saving

    private func move(
        _ window: WorkspaceWindow, to display: WorkspaceDisplay?, in workspace: ChapWorkspace
    ) {
        save(
            workspace,
            windows: workspace.windows.map { $0.id == window.id ? $0.assigned(to: display) : $0 })
    }

    private func save(_ workspace: ChapWorkspace, windows: [WorkspaceWindow]) {
        library.replace(workspace.id, name: workspace.name, windows: windows)
    }

    private func commitName() {
        guard let workspace else { return }
        guard let cleaned = WorkspaceStore.cleanedName(nameDraft) else {
            // 비운 이름은 저장하지 않고 원래 이름으로 돌린다.
            nameDraft = workspace.name
            return
        }
        nameDraft = cleaned
        guard cleaned != workspace.name else { return }
        library.replace(workspace.id, name: cleaned, windows: workspace.windows)
    }
}
