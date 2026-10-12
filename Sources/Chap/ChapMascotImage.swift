import Cocoa

/// Chap(픽셀 물범)을 AppKit 이미지로 그린다. 노치는 SwiftUI `NotchMascotView`가 같은 격자를
/// 그리므로, 여기서는 NSView·NSImage가 필요한 자리(중앙 HUD 등)만 담당한다.
/// 색은 `DESIGN.md`의 마스코트 잉크와 같다.
enum ChapMascotImage {
    static let outline = NSColor(red: 0x16 / 255, green: 0x1A / 255, blue: 0x30 / 255, alpha: 1)
    static let body = NSColor.white
    static let shade = NSColor(red: 0xB0 / 255, green: 0xBE / 255, blue: 0xD8 / 255, alpha: 1)

    private static func color(for symbol: Character) -> NSColor? {
        switch symbol {
        case "o", "e": return outline
        case "w": return body
        case "s": return shade
        default: return nil
        }
    }

    /// 한 칸을 `pixelSize`pt 정사각형으로 그린 물범. 잠든 모습이면 머리 위에 z도 함께.
    /// 칸 크기를 정수 pt로 주면 Retina에서도 칸 경계가 또렷하다.
    static func image(
        pixelSize: CGFloat, eyes: ChapMascot.Eyes = .open, pose: ChapMascot.Pose = .rest,
        showsSleepZ: Bool = false
    ) -> NSImage {
        // z는 머리 오른쪽 위에 겹치므로 위로 4칸, 오른쪽은 격자 안에 들어간다.
        let topPadding = showsSleepZ ? 4 : 0
        let size = NSSize(
            width: CGFloat(ChapMascot.width) * pixelSize,
            height: CGFloat(ChapMascot.height + topPadding) * pixelSize)
        let rows = ChapMascot.rows(eyes: eyes, pose: pose)
        let image = NSImage(size: size, flipped: true) { _ in
            func fill(x: Int, y: Int, _ nsColor: NSColor) {
                nsColor.setFill()
                NSRect(
                    x: CGFloat(x) * pixelSize, y: CGFloat(y + topPadding) * pixelSize,
                    width: pixelSize, height: pixelSize
                ).fill()
            }
            for (y, row) in rows.enumerated() {
                for (x, symbol) in row.enumerated() {
                    if let nsColor = color(for: symbol) { fill(x: x, y: y, nsColor) }
                }
            }
            if showsSleepZ {
                // 노치와 같은 자리: 머리 오른쪽 위.
                for (y, row) in ChapMascot.sleepZRows.enumerated() {
                    for (x, symbol) in row.enumerated() where symbol == "o" {
                        fill(x: x + 11, y: y - topPadding, body)
                    }
                }
            }
            return true
        }
        image.accessibilityDescription = "Chap"
        return image
    }
}
