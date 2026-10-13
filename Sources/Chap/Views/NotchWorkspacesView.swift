import SwiftUI

/// 저장된 작업 공간을 한 번에 복원하고 새 배치를 캡처하는 노치 위젯.
struct NotchWorkspacesView: View {
    let workspaces: [ChapWorkspace]
    /// 지금 열리는 중인 Workspace. 그 줄의 숫자가 진행 표시로 바뀐다.
    var busyID: UUID? = nil
    let palette: NotchWidgetPalette
    let onOpen: (UUID) -> Void
    let onCapture: () -> Void
    var onEdit: (UUID) -> Void = { _ in }
    var onRemove: (UUID) -> Void = { _ in }
    /// 제목 클릭: 설정창 Launchers의 Workspaces 섹션을 연다(다른 런처 칸 제목과 같은 동작).
    var onOpenSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            NotchSectionTitleButton(
                symbol: "rectangle.3.group", title: "Workspaces",
                foreground: palette.heading,
                iconForeground: palette.icon ?? palette.heading,
                hoverBackground: palette.hoverBackground,
                textShadowOpacity: palette.textShadowOpacity,
                action: onOpenSettings)
            VStack(alignment: .leading, spacing: NotchAppIconTile.listRowSpacing) {
                ForEach(workspaces.prefix(WorkspaceStore.maxWorkspaces)) { workspace in
                    WorkspaceRow(
                        workspace: workspace, isBusy: busyID == workspace.id, palette: palette
                    ) {
                        onOpen(workspace.id)
                    }
                    .contextMenu {
                        Button("Open") { onOpen(workspace.id) }
                        Button("Edit…") { onEdit(workspace.id) }
                        Divider()
                        Button("Remove…", role: .destructive) { onRemove(workspace.id) }
                    }
                    .accessibilityAction(named: "Edit") { onEdit(workspace.id) }
                    .accessibilityAction(named: "Remove") { onRemove(workspace.id) }
                }
                if workspaces.count < WorkspaceStore.maxWorkspaces {
                    captureRow
                }
            }
            .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
        }
    }

    private var captureRow: some View {
        Button(action: onCapture) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: DS.notchRowIconSize, height: DS.notchRowIconSize)
                Text("Capture")
                    .font(DS.notchRowName.weight(.medium))
                Spacer(minLength: 0)
            }
            .foregroundColor(palette.secondary)
            .padding(.horizontal, 6)
            .frame(height: NotchAppIconTile.listRowHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(palette.subtleSurface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Capture the open app windows")
        .accessibilityLabel("Capture Workspace")
    }
}

private struct WorkspaceRow: View {
    let workspace: ChapWorkspace
    let isBusy: Bool
    let palette: NotchWidgetPalette
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.accent)
                    .frame(width: DS.notchRowIconSize, height: DS.notchRowIconSize)
                Text(workspace.name)
                    .font(DS.notchRowName)
                    .foregroundColor(palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if isBusy {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 12, height: 12)
                        .accessibilityLabel("Opening")
                } else {
                    Text("\(workspace.windows.count)")
                        .font(DS.notchMeta)
                        .foregroundColor(palette.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 6)
            .frame(height: NotchAppIconTile.listRowHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? palette.hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .onHover { isHovered = $0 }
        .help(workspace.windows.map(\.applicationName).joined(separator: ", "))
        .accessibilityLabel(
            "Open \(workspace.name), \(workspace.windows.count) app windows")
    }
}
