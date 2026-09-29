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
        let downloads = await withCheckedContinuation { continuation in
            DownloadsShelf.recentFilesAsync { continuation.resume(returning: $0) }
        }
        DownloadsShelf.previewOverride = downloads
        // 렌더에는 다운로드 칸을 빈 칸 자리에 넣어 본다 (설정 파일은 바꾸지 않는다).
        var previewWidgets = config.notchWidgets
        if !previewWidgets.contains(.downloads), let gap = previewWidgets.firstIndex(of: .none) {
            previewWidgets[gap] = .downloads
        }
        if !previewWidgets.contains(.awake), let gap = previewWidgets.firstIndex(of: .none) {
            previewWidgets[gap] = .awake
        }
        let previewSlots = NotchSlotContent.slots(widgets: previewWidgets, sites: config.sites)
        let drops = await withCheckedContinuation { continuation in
            ChapDrop.recentFilesAsync(limit: DropPolicy.maxDockItems) {
                continuation.resume(returning: $0)
            }
        }
        ChapDrop.previewOverride = drops
        defer {
            ScreenshotShelf.previewOverride = nil
            DownloadsShelf.previewOverride = nil
            ChapDrop.previewOverride = nil
        }

        let variants: [(String, NotchPanelStyle, ColorScheme, Color, Bool)] = [
            ("notch-glass-light", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-empty-drop", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-note", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-focus-on", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-option", .glass, .light, Color(white: 0.92), true),
            ("notch-glass-dark", .glass, .dark, Color(white: 0.16), false),
            ("notch-custom", .custom, .dark, Color(white: 0.55), false),
        ]
        for (name, style, scheme, backdrop, optionHeld) in variants {
            // 빈 Drop 상태(상자만, 숫자 없음)도 한 장 그린다.
            ChapDrop.previewOverride = name.hasSuffix("empty-drop") ? [] : drops
            // 비동기로 채우는 이미지를 그리기 직전에 캐시에 넣는다 (NSCache는 언제든 비울 수 있다).
            for site in config.sites where site.launchType == .app {
                if let path = site.appPath { _ = await AppIconLoader.icon(forAppPath: path) }
            }
            for url in shots { _ = await ThumbnailLoader.image(for: url, maxPixelSize: 96) }
            // 캐시가 비워질 수 있으니 그리기 직전에 한 번 더 채운다.
            for site in config.sites where site.launchType == .app {
                if let path = site.appPath { _ = await AppIconLoader.icon(forAppPath: path) }
            }
            let reveal = NotchRevealModel()
            reveal.revealed = true
            reveal.isOptionHeld = optionHeld
            reveal.isNoteMode = name.hasSuffix("-note")
            reveal.bottomOpacity = config.notchPanelOpacity
            reveal.colorHex = config.notchPanelColorHex
            let panel = NotchLauncherPanelView(
                minWidth: NotchLauncherPolicy.dockMinWidth(notchWidth: 185), topInset: 32,
                stripPlateauHalfWidth: 92.5 + 110,
                awakeSessionEnd: name.hasSuffix("focus-on")
                    ? Date().addingTimeInterval(3 * 3600 + 25 * 60) : nil, style: style,
                glassMaterial: config.notchGlassMaterial,
                slots: previewSlots, showsMirror: config.notchMirrorEnabled,
                showsNote: config.notchQuickNoteEnabled, onLaunch: { _ in },
                reveal: reveal)
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

    /// 메모 모드를 켜고 끌 때 도커가 SwiftUI로 잰 크기를 컨트롤러에 알리는지 확인한다.
    /// 실제 앱처럼 창 안에 올린 뒤 모드를 바꾸고, 보고된 높이가 늘었다 줄어드는지 본다.
    @Test(
        "note mode reports a taller dock size and returns when closed",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func noteModeReportsSize() throws {
        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default
        let slots = NotchSlotContent.slots(widgets: config.notchWidgets, sites: config.sites)
        let reveal = NotchRevealModel()
        reveal.revealed = true
        var reported: [CGSize] = []
        let panel = NotchLauncherPanelView(
            minWidth: NotchLauncherPolicy.dockMinWidth(notchWidth: 185), topInset: 32,
            stripPlateauHalfWidth: 92.5 + 110, awakeSessionEnd: nil, style: .glass,
            glassMaterial: .regular, slots: slots, showsMirror: true, showsNote: true,
            onLaunch: { _ in }, onContentSizeChange: { reported.append($0) }, reveal: reveal)
        let hosting = NSHostingView(rootView: panel)
        hosting.safeAreaRegions = []
        let size = hosting.fittingSize
        let window = NSWindow(
            contentRect: CGRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.3)) }

        settle()
        let normal = try #require(reported.last)
        reveal.isNoteMode = true
        settle()
        let note = try #require(reported.last)
        reveal.isNoteMode = false
        settle()
        let back = try #require(reported.last)

        #expect(note.height > normal.height + 50, "normal \(normal) note \(note)")
        #expect(back.height == normal.height, "normal \(normal) back \(back)")
    }

    /// 실제 앱처럼 Drop 파일 목록이 창을 연 뒤에 비동기로 채워질 때, 도커가 창 크기에 눌리지
    /// 않은 본래 높이를 보고하는지 확인한다 (눌린 높이를 보고하면 창이 커지지 않아 줄이 겹친다).
    @Test(
        "late-loading Drop files report the dock's natural height, not the window's",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func lateDropFilesReportNaturalHeight() async throws {
        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default
        let slots = NotchSlotContent.slots(widgets: config.notchWidgets, sites: config.sites)
        let hasDropFiles =
            !(try FileManager.default.contentsOfDirectory(
                at: ChapDrop.directory(), includingPropertiesForKeys: nil
            ).filter { !$0.lastPathComponent.hasPrefix(".") }.isEmpty)
        try #require(hasDropFiles, "needs at least one Chap Drop file to reproduce")
        ChapDrop.previewOverride = nil
        ScreenshotShelf.previewOverride = nil
        let reveal = NotchRevealModel()
        reveal.revealed = true
        var reported: [CGSize] = []
        let panel = NotchLauncherPanelView(
            minWidth: NotchLauncherPolicy.dockMinWidth(notchWidth: 185), topInset: 32,
            stripPlateauHalfWidth: 92.5 + 110, awakeSessionEnd: nil, style: .glass,
            glassMaterial: .regular, slots: slots, showsMirror: true, showsNote: true,
            onLaunch: { _ in }, onContentSizeChange: { reported.append($0) }, reveal: reveal)
        let hosting = NSHostingView(rootView: panel)
        hosting.safeAreaRegions = []
        // 앱과 같이: 파일이 아직 없을 때 잰 크기로 창을 만든다.
        let initial = hosting.fittingSize
        let window = NSWindow(
            contentRect: CGRect(
                x: -10_000, y: -10_000, width: initial.width, height: initial.height),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        // 메인 액터를 양보해야 메인 큐 completion(Drop 목록)이 실행된다.
        try await Task.sleep(for: .milliseconds(900))

        var direct: [URL] = []
        ChapDrop.recentFilesAsync(limit: DropPolicy.maxDockItems) { direct = $0 }
        try await Task.sleep(for: .milliseconds(400))
        let after = hosting.fittingSize
        let last = try #require(reported.last)
        #expect(
            last.height > initial.height + 20,
            "initial \(initial) after \(after) direct \(direct.count) reported \(reported)")
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
