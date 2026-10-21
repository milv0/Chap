import SwiftUI

/// 크기 프리셋을 창 모양 썸네일로 바로 고르는 격자. 윗줄은 가로형, 아랫줄은 세로형과 Custom이다.
/// `selection`은 `presets` 안의 순번 + 1이고, 0은 Custom이다(목록에서 뺀 프리셋은 -1이라 어느 칸도 고르지 않는다).
/// 마우스를 올리면 `hoveredSelection`으로 미니맵에 미리 보여준다.
struct SizePresetGrid: View {
    let presets: [WindowSizePreset]
    let selectedSelection: Int
    @Binding var hoveredSelection: Int?
    let onSelect: (Int) -> Void

    /// 한 줄에 놓는 칸 수. 가로형 여섯 개가 한 줄에 들어간다.
    static let columnCount = 6
    /// 썸네일 속 화면 크기(pt). 16:10.
    static let screenSize = CGSize(width: 36, height: 22.5)

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: Self.columnCount)
    }

    private var orderedTiles: [Tile] {
        let indexed = presets.enumerated().map { Tile.preset($0.element, selection: $0.offset + 1) }
        let landscape = indexed.filter { $0.orientation == .landscape }
        let portrait = indexed.filter { $0.orientation == .portrait }
        return landscape + portrait + [.custom]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(orderedTiles) { tile in
                tileView(tile)
            }
        }
    }

    private func tileView(_ tile: Tile) -> some View {
        let isSelected = selectedSelection == tile.selection
        let isHovered = hoveredSelection == tile.selection
        return VStack(spacing: 3) {
            thumbnail(tile, isSelected: isSelected)
            // 가장 긴 "Comfortable"도 칸 안쪽에 여유가 남는 크기.
            Text(tile.label)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? DS.accent : DS.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        // 칸마다 테두리를 두르지 않는다. 고른 칸만 옅은 강조색, 올린 칸은 더 옅게.
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected
                        ? DS.accentSoft : (isHovered ? DS.border.opacity(0.18) : Color.clear))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            if hovering {
                hoveredSelection = tile.selection
            } else if hoveredSelection == tile.selection {
                hoveredSelection = nil
            }
        }
        .onTapGesture { onSelect(tile.selection) }
        .help(tile.help)
        .accessibilityElement()
        .accessibilityLabel("\(tile.label) size")
        .accessibilityHint(tile.help)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect(tile.selection) }
    }

    /// 화면 테두리 안에 창 크기만큼 채운 사각형. Custom은 점선 테두리 안에 연필.
    private func thumbnail(_ tile: Tile, isSelected: Bool) -> some View {
        let screen = Self.screenSize
        let ink = isSelected ? DS.accent : DS.textSecondary
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(DS.textTertiary, lineWidth: 1)
            switch tile {
            case .preset(let preset, _):
                let window = Self.windowSize(for: preset)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(ink.opacity(isSelected ? 0.85 : 0.45))
                    .frame(width: window.width, height: window.height)
            case .custom:
                RoundedRectangle(cornerRadius: 1.5)
                    .strokeBorder(ink, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: screen.width * 0.6, height: screen.height * 0.6)
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(ink)
            }
        }
        .frame(width: screen.width, height: screen.height)
    }

    /// 1600×1000 가상 화면에서 프리셋 크기를 구해 썸네일 화면 크기로 줄인다(테두리 1pt 안쪽).
    static func windowSize(for preset: WindowSizePreset) -> CGSize {
        let size = windowSizeFromRatio(
            widthRatio: preset.widthRatio, heightRatio: preset.heightRatio,
            aspectRatio: preset.aspectRatio, visibleWidth: 1600, visibleHeight: 1000)
        let inner = CGSize(width: screenSize.width - 4, height: screenSize.height - 4)
        return CGSize(
            width: inner.width * CGFloat(size.width) / 1600,
            height: inner.height * CGFloat(size.height) / 1000)
    }

    enum Tile: Identifiable {
        case preset(WindowSizePreset, selection: Int)
        case custom

        var id: String {
            switch self {
            case .preset(let preset, _): return preset.id
            case .custom: return "custom"
            }
        }

        var selection: Int {
            switch self {
            case .preset(_, let selection): return selection
            case .custom: return 0
            }
        }

        var label: String {
            switch self {
            case .preset(let preset, _): return preset.label
            case .custom: return "Custom"
            }
        }

        var orientation: WindowSizePreset.Orientation? {
            if case .preset(let preset, _) = self { return preset.orientation }
            return nil
        }

        var help: String {
            switch self {
            case .preset(let preset, _) where preset.aspectRatio != nil:
                let width = Int((preset.widthRatio * 100).rounded())
                return "\(preset.label): \(preset.ratioText), \(width)% of the screen wide"
            case .preset(let preset, _):
                return "\(preset.label): \(preset.ratioText) of the screen"
            case .custom: return "Type your own width and height"
            }
        }
    }
}
