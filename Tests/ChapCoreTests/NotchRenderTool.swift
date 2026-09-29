import AppKit
import SwiftUI
import Testing

@testable import Chap

/// 개발용 노치 오프스크린 렌더 도구. 평소 테스트 실행에서는 건너뛴다.
///
///     TEST_RUNNER_CHAP_NOTCH_RENDER_DIR=/path/to/dir xcodebuild ... test
///
/// 현재 `~/.chap.json`, 스크린샷 폴더, Chap Drop 파일로 실제와 같은 도커를 그려
/// `notch-glass-light.png`, `notch-glass-dark.png`, `notch-custom.png`를 저장한다.
/// Liquid Glass 재질과 NSView 기반 뷰(메모 입력칸, 카메라 미리보기)는 오프스크린에서
/// 그려지지 않으므로 Glass는 비슷한 밝기의 배경 위 투명 도커로 근사한다.
@Suite("Notch render tool")
@MainActor
struct NotchRenderTool {
    static let outputDirectory = ProcessInfo.processInfo.environment["CHAP_NOTCH_RENDER_DIR"]

    @Test(
        "render the notch dock to PNG",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func render() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default
        let slots = NotchSlotContent.slots(widgets: config.notchWidgets, sites: config.sites)

        let shots = await withCheckedContinuation { continuation in
            ScreenshotShelf.recentScreenshotsAsync { continuation.resume(returning: $0) }
        }
        ScreenshotShelf.previewOverride = shots
        let drops = await withCheckedContinuation { continuation in
            ChapDrop.recentFilesAsync(limit: DropPolicy.maxDockItems) {
                continuation.resume(returning: $0)
            }
        }
        ChapDrop.previewOverride = drops
        defer {
            ScreenshotShelf.previewOverride = nil
            ChapDrop.previewOverride = nil
        }

        let variants: [(String, NotchPanelStyle, ColorScheme, Color, Bool)] = [
            ("notch-glass-light", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-option", .glass, .light, Color(white: 0.92), true),
            ("notch-glass-dark", .glass, .dark, Color(white: 0.16), false),
            ("notch-custom", .custom, .dark, Color(white: 0.55), false),
        ]
        for (name, style, scheme, backdrop, optionHeld) in variants {
            // 비동기로 채우는 이미지를 그리기 직전에 캐시에 넣는다 (NSCache는 언제든 비울 수 있다).
            for site in config.sites where site.launchType == .app {
                if let path = site.appPath { _ = await AppIconLoader.icon(forAppPath: path) }
            }
            for url in shots { _ = await ThumbnailLoader.image(for: url, maxPixelSize: 96) }
            let reveal = NotchRevealModel()
            reveal.revealed = true
            reveal.isOptionHeld = optionHeld
            reveal.bottomOpacity = config.notchPanelOpacity
            reveal.colorHex = config.notchPanelColorHex
            let panel = NotchLauncherPanelView(
                minWidth: 265, topInset: 32, stripPlateauHalfWidth: 92.5 + 110,
                awakeSessionEnd: nil, style: style, glassMaterial: config.notchGlassMaterial,
                slots: slots, onLaunch: { _ in }, reveal: reveal)
            let view =
                panel
                .fixedSize()
                .padding(24)
                .background(backdrop)
                .environment(\.colorScheme, scheme)
            // ImageRenderer는 AppKit 기반 뷰가 섞이면 전체를 대체 이미지로 그린다.
            // 화면 밖 창에 NSHostingView를 올려 레이어를 직접 비트맵으로 그린다.
            let png = try Self.renderPNG(view)
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    static func renderPNG<V: View>(_ view: V) throws -> Data {
        let hosting = NSHostingView(rootView: view)
        hosting.safeAreaRegions = []
        let size = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: CGRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        hosting.layoutSubtreeIfNeeded()
        // SwiftUI가 한 번 그릴 시간을 준다.
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        hosting.displayIfNeeded()
        let scale: CGFloat = 2
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = size
        let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cg = context.cgContext
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)
        try #require(hosting.layer).render(in: cg)
        NSGraphicsContext.restoreGraphicsState()
        return try #require(rep.representation(using: .png, properties: [:]))
    }
}
