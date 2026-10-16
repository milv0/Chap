import SwiftUI

/// 저장된 창 배치를 한 번에 복원하고 새 배치를 캡처하는 격자. Apps 칸의 Layouts 탭 본문이다
/// (제목 줄은 Apps 칸의 탭이 맡는다). 2열 타일 격자다. 타일은 그 Layout 앱 아이콘을 최대 넷 모은 묶음(폴더 아이콘처럼)과
/// 아래 짧은 이름이다. Layout은 같은 앱 조합이 겹칠 수 있어 이름을 늘 함께 보여 준다.
/// 최대 4개라 2×2에 맞고, 4개 미만이면 빈 자리에 점선 + 타일(Capture)이 들어간다.
struct NotchLayoutsView: View {
    let layouts: [ChapLayout]
    /// 지금 열리는 중인 Layout. 그 타일 위에 진행 표시가 돈다.
    var busyID: UUID? = nil
    let palette: NotchWidgetPalette
    let onOpen: (UUID) -> Void
    let onCapture: () -> Void
    var onEdit: (UUID) -> Void = { _ in }
    var onRemove: (UUID) -> Void = { _ in }

    /// 타일 폭. 이름보다 아이콘 묶음 간격을 앞세워 Apps 탭처럼 촘촘하게 둔다(묶음 사이 약 24pt).
    /// 긴 이름은 끝을 줄이고, 마우스를 올리면 툴팁에 전체 이름이 보인다.
    static let tileWidth: CGFloat = 48
    /// 아이콘 묶음 한 변. Apps 탭 앱 아이콘(32pt)과 같아 탭을 바꿔도 한 칸처럼 보인다.
    static let clusterSize: CGFloat = 32
    static let clusterCornerRadius: CGFloat = 8
    static let columnGap: CGFloat = 8
    /// 칸 폭: 2열 타일 + 간격 + 좌우 여백.
    static var columnWidth: CGFloat { 2 * tileWidth + columnGap + 4 }

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.fixed(Self.tileWidth), spacing: Self.columnGap),
                count: 2),
            // 줄 간격 8pt: 묶음을 32pt로 줄여 생긴 여유(두 줄 × 4pt)를 줄 사이에 둔다. 타일 위아래 여백
            // 2pt씩을 더하면 위 이름과 아래 묶음 사이가 12pt이고, 두 줄은 다른 칸 바닥선 안에 든다.
            alignment: .center, spacing: 8
        ) {
            ForEach(layouts.prefix(LayoutStore.maxLayouts)) { layout in
                LayoutTile(
                    layout: layout, isBusy: busyID == layout.id, palette: palette
                ) {
                    onOpen(layout.id)
                }
                .contextMenu {
                    Button("Open") { onOpen(layout.id) }
                    Button("Edit…") { onEdit(layout.id) }
                    Divider()
                    Button("Remove…", role: .destructive) { onRemove(layout.id) }
                }
                .accessibilityAction(named: "Edit") { onEdit(layout.id) }
                .accessibilityAction(named: "Remove") { onRemove(layout.id) }
            }
            if layouts.count < LayoutStore.maxLayouts {
                CaptureTile(palette: palette, action: onCapture)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Layout 하나: 앱 아이콘 묶음 + 이름. 누르면 연다.
private struct LayoutTile: View {
    let layout: ChapLayout
    let isBusy: Bool
    let palette: NotchWidgetPalette
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                LayoutIconCluster(
                    paths: layout.windows.map(\.applicationPath), palette: palette
                )
                .overlay {
                    if isBusy {
                        RoundedRectangle(
                            cornerRadius: NotchLayoutsView.clusterCornerRadius,
                            style: .continuous
                        )
                        .fill(.black.opacity(0.35))
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
                Text(layout.name)
                    .font(DS.notchMeta)
                    .foregroundColor(palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: NotchLayoutsView.tileWidth - 4)
            }
            .padding(.vertical, 2)
            .frame(width: NotchLayoutsView.tileWidth)
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
            "\(layout.name) — "
                + layout.windows.map(\.applicationName).joined(separator: ", ")
        )
        .accessibilityLabel(
            "Open \(layout.name), "
                + layout.windows.map(\.applicationName).joined(separator: ", ")
        )
        .accessibilityValue(isBusy ? "Opening" : "")
    }
}

/// 폴더 아이콘처럼 앱 아이콘을 모은 사각형. 앱이 하나면 크게 하나, 둘 이상이면 2×2 격자에 앞에서부터 넷.
struct LayoutIconCluster: View {
    let paths: [String]
    let palette: NotchWidgetPalette

    private static let size = NotchLayoutsView.clusterSize
    private static let inset: CGFloat = 2
    private static let gap: CGFloat = 2
    private static var smallIcon: CGFloat { (size - 2 * inset - gap) / 2 }

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: NotchLayoutsView.clusterCornerRadius, style: .continuous
            )
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
                RoundedRectangle(
                    cornerRadius: NotchLayoutsView.clusterCornerRadius, style: .continuous
                )
                .strokeBorder(
                    palette.secondary.opacity(isHovered ? 0.8 : 0.45),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])
                )
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isHovered ? DS.accent : palette.secondary)
                }
                .frame(
                    width: NotchLayoutsView.clusterSize,
                    height: NotchLayoutsView.clusterSize)
                Text("Capture")
                    .font(DS.notchMeta)
                    .foregroundColor(isHovered ? DS.accent : palette.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)
            .frame(width: NotchLayoutsView.tileWidth)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? palette.hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Capture the open app windows")
        .accessibilityLabel("Capture Layout")
    }
}
