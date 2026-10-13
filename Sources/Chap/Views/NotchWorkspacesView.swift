import SwiftUI

/// 저장된 작업 공간을 한 번에 복원하고 새 배치를 캡처하는 노치 위젯.
/// Apps 칸처럼 2열 타일 격자다. 타일은 그 Workspace 앱 아이콘을 최대 넷 모은 묶음(폴더 아이콘처럼)과
/// 아래 짧은 이름이다. Workspace는 같은 앱 조합이 겹칠 수 있어 이름을 늘 함께 보여 준다.
/// 최대 4개라 2×2에 맞고, 4개 미만이면 빈 자리에 점선 + 타일(Capture)이 들어간다.
struct NotchWorkspacesView: View {
    let workspaces: [ChapWorkspace]
    /// 지금 열리는 중인 Workspace. 그 타일 위에 진행 표시가 돈다.
    var busyID: UUID? = nil
    let palette: NotchWidgetPalette
    let onOpen: (UUID) -> Void
    let onCapture: () -> Void
    var onEdit: (UUID) -> Void = { _ in }
    var onRemove: (UUID) -> Void = { _ in }
    /// 제목 클릭: 설정창 Launchers의 Workspaces 섹션을 연다(다른 런처 칸 제목과 같은 동작).
    var onOpenSettings: () -> Void = {}

    static let tileWidth: CGFloat = 58
    static let clusterSize: CGFloat = 36
    static let columnGap: CGFloat = 8
    /// 칸 폭: 2열 타일 + 간격 + 좌우 여백.
    static var columnWidth: CGFloat { 2 * tileWidth + columnGap + 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            NotchSectionTitleButton(
                symbol: "rectangle.3.group", title: "Workspaces",
                foreground: palette.heading,
                iconForeground: palette.icon ?? palette.heading,
                hoverBackground: palette.hoverBackground,
                textShadowOpacity: palette.textShadowOpacity,
                action: onOpenSettings)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(Self.tileWidth), spacing: Self.columnGap),
                    count: 2),
                alignment: .center, spacing: 6
            ) {
                ForEach(workspaces.prefix(WorkspaceStore.maxWorkspaces)) { workspace in
                    WorkspaceTile(
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
                    CaptureTile(palette: palette, action: onCapture)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
        }
    }
}

/// Workspace 하나: 앱 아이콘 묶음 + 이름. 누르면 연다.
private struct WorkspaceTile: View {
    let workspace: ChapWorkspace
    let isBusy: Bool
    let palette: NotchWidgetPalette
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                WorkspaceIconCluster(
                    paths: workspace.windows.map(\.applicationPath), palette: palette
                )
                .overlay {
                    if isBusy {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.black.opacity(0.35))
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
                Text(workspace.name)
                    .font(DS.notchMeta)
                    .foregroundColor(palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: NotchWorkspacesView.tileWidth - 4)
            }
            .padding(.vertical, 2)
            .frame(width: NotchWorkspacesView.tileWidth)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? palette.hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .onHover { isHovered = $0 }
        .help(
            "\(workspace.name) — "
                + workspace.windows.map(\.applicationName).joined(separator: ", ")
        )
        .accessibilityLabel(
            "Open \(workspace.name), "
                + workspace.windows.map(\.applicationName).joined(separator: ", ")
        )
        .accessibilityValue(isBusy ? "Opening" : "")
    }
}

/// 폴더 아이콘처럼 앱 아이콘을 모은 사각형. 앱이 하나면 크게 하나, 둘 이상이면 2×2 격자에 앞에서부터 넷.
struct WorkspaceIconCluster: View {
    let paths: [String]
    let palette: NotchWidgetPalette

    private static let size = NotchWorkspacesView.clusterSize
    private static let inset: CGFloat = 3
    private static let gap: CGFloat = 2
    private static var smallIcon: CGFloat { (size - 2 * inset - gap) / 2 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.subtleSurface)
            if paths.count == 1 {
                ClusterIcon(path: paths[0], size: Self.size - 8)
            } else {
                // 줄마다 앞에서부터 둘씩. 둘이면 한 줄, 셋이면 아래 하나를 가운데에 두어 묶음이 기울지 않는다.
                let shown = Array(paths.prefix(4))
                let rows = stride(from: 0, to: shown.count, by: 2).map {
                    Array(shown[$0..<min($0 + 2, shown.count)])
                }
                VStack(spacing: Self.gap) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: Self.gap) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, path in
                                ClusterIcon(path: path, size: Self.smallIcon)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }
}

/// 묶음 안의 앱 아이콘 하나. Apps 칸과 같은 캐시(`AppIconLoader`)를 쓴다.
private struct ClusterIcon: View {
    let path: String
    let size: CGFloat
    @State private var icon: NSImage?

    init(path: String, size: CGFloat) {
        self.path = path
        self.size = size
        _icon = State(initialValue: AppIconLoader.cachedIcon(forAppPath: path))
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: "app.fill").resizable().foregroundColor(.secondary.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
        .task(id: path) {
            if icon == nil { icon = await AppIconLoader.icon(forAppPath: path) }
        }
    }
}

/// 빈 자리의 점선 + 타일. 누르면 지금 창 배치를 캡처한다.
private struct CaptureTile: View {
    let palette: NotchWidgetPalette
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        palette.secondary.opacity(isHovered ? 0.8 : 0.45),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])
                    )
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isHovered ? DS.accent : palette.secondary)
                    }
                    .frame(
                        width: NotchWorkspacesView.clusterSize,
                        height: NotchWorkspacesView.clusterSize)
                Text("Capture")
                    .font(DS.notchMeta)
                    .foregroundColor(isHovered ? DS.accent : palette.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)
            .frame(width: NotchWorkspacesView.tileWidth)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? palette.hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Capture the open app windows")
        .accessibilityLabel("Capture Workspace")
    }
}
