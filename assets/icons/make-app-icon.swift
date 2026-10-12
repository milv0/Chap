import AppKit

// Chap 앱 아이콘(픽셀 물범) 생성기. 1024×1024 PNG 하나를 만든다.
// 실행: xcrun swift assets/icons/make-app-icon.swift [출력 경로]
// icns로 굽는 법은 같은 폴더의 README.md를 본다.
// 그림은 Sources/ChapCore/ChapMascot.swift의 격자, 색은 DESIGN.md의 마스코트 잉크와 같다.

// ChapMascot 격자 (앱과 같은 그림, 쉬는 자세).
let rows = [
    ".....oooo...............",
    "....owwwwoo.............",
    "...owwwwwwwo............",
    "..owwwwwwwwwoooo........",
    "..owewwewwwwwwwwoo......",
    "..owwwwwwwwwwwwwwwo.....",
    "..owwoowwwwwwwwwwwwo..oo",
    ".oswwwwwwwwwwwwwwwwwoowo",
    "oswswwwwwwwwwwwwwwwwwwo.",
    "ossoossswwwwwwwwsssssswo",
    ".oo..oosssssssssooooooo.",
    ".......ooooooooo........",
]
let spriteW = 24
let spriteH = 12

func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return NSColor(
        srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
        blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let outline = color("#161A30")
let body = color("#FFFFFF")
let shade = color("#B0BED8")
let crest = color("#6E91FF")
let waterDeep = color("#2440AA")

func ink(_ c: Character) -> NSColor? {
    switch c {
    case "o", "e": return outline
    case "w": return body
    case "s": return shade
    default: return nil
    }
}

/// 아이콘 한 장의 설정. 값은 2.8.4에서 고른 것이며, 다시 뽑아도 같은 그림이 나온다.
struct Variant {
    let name: String
    let sky: (String, String)
    let pixel: CGFloat
    /// 수면선 아래 깊은 물 줄 수. 0이면 마루 한 줄만.
    let deepRows: Int
    /// 수면선만 아래로 내리는 양(px). 물범 자리는 그대로다.
    let waterDrop: CGFloat
}

let variants = [
    Variant(
        name: "app-icon-1024", sky: ("#4C78FF", "#244CDC"), pixel: 38, deepRows: 1, waterDrop: 57)
]

let side: CGFloat = 1024
let radius: CGFloat = 225

for variant in variants {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current?.imageInterpolation = .none

    NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: side, height: side), xRadius: radius,
        yRadius: radius
    ).addClip()
    NSGradient(starting: color(variant.sky.0), ending: color(variant.sky.1))!
        .draw(in: NSRect(x: 0, y: 0, width: side, height: side), angle: -90)

    let pixel = variant.pixel
    let spriteWidth = CGFloat(spriteW) * pixel
    let spriteHeight = CGFloat(spriteH) * pixel
    // 수면선은 물범 아래 한 줄(+깊은 물). 물범 + 수면선 묶음을 캔버스 가운데에 둔다.
    // 물결 마루가 한 칸 오르내리므로 묶음 높이에 그 한 칸을 더해 센다.
    let lineUnits: CGFloat = 3  // v4-38과 같은 물범 자리 (마루 + 깊은 물 + 물결 한 칸)
    let blockHeight = spriteHeight + lineUnits * pixel
    let originX = ((side - spriteWidth) / 2).rounded()
    let originY = (side - ((side - blockHeight) / 2).rounded() - spriteHeight).rounded()

    func fill(x: Int, y: Int, _ nsColor: NSColor, dropY: CGFloat = 0) {
        nsColor.setFill()
        NSBezierPath(
            rect: NSRect(
                x: originX + CGFloat(x) * pixel,
                y: originY + CGFloat(spriteH - 1 - y) * pixel - dropY,
                width: pixel, height: pixel)
        ).fill()
    }

    // 얇은 수면선: 물범 바로 아래부터, 아이콘 좌우 끝까지 가로지른다.
    for x in -8..<(spriteW + 8) {
        let top = spriteH + (((x % 4) + 4) % 4 < 2 ? 0 : 1)
        fill(x: x, y: top, crest, dropY: variant.waterDrop)
        if variant.deepRows > 0 {
            for y in (top + 1)...(top + variant.deepRows) {
                fill(x: x, y: y, waterDeep, dropY: variant.waterDrop)
            }
        }
    }

    for (y, row) in rows.enumerated() {
        for (x, char) in row.enumerated() {
            if let nsColor = ink(char) { fill(x: x, y: y, nsColor) }
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    let output =
        CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : FileManager.default.currentDirectoryPath + "/\(variant.name).png"
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("could not encode PNG")
        exit(1)
    }
    do {
        try png.write(to: URL(fileURLWithPath: output))
    } catch {
        print("could not write \(output): \(error.localizedDescription)")
        exit(1)
    }
    print("wrote", output)
}
