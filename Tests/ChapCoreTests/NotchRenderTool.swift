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
@Suite("Notch render tool", .serialized)
@MainActor
struct NotchRenderTool {
    /// `.enabled(if:)` 조건은 비동기 컨텍스트에서 읽으므로 main actor에 묶지 않는다.
    nonisolated static let outputDirectory = ProcessInfo.processInfo.environment[
        "CHAP_NOTCH_RENDER_DIR"]

    @Test(
        "render the notch dock to PNG",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func render() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default

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
        // 할 일 칸 미리보기: 마지막 위젯 칸을 To-do로 바꾼다 (설정 파일은 바꾸지 않는다).
        var todoWidgets = previewWidgets
        if !todoWidgets.contains(.todo) { todoWidgets[NotchWidget.slotCount - 1] = .todo }
        let todoSlots = NotchSlotContent.slots(widgets: todoWidgets, sites: config.sites)
        var workspaceWidgets = previewWidgets
        if !workspaceWidgets.contains(.workspaces) {
            workspaceWidgets[NotchWidget.slotCount - 1] = .workspaces
        }
        let previewWorkspaces = Self.previewWorkspaces
        let workspaceSlots = NotchSlotContent.slots(
            widgets: workspaceWidgets, sites: config.sites, workspaces: previewWorkspaces)
        let now = Date()
        NotchTodoView.previewItems = [
            TodoItem(title: "Send the Q4 deck to Jun", created: now),
            TodoItem(title: "Book dentist", created: now.addingTimeInterval(1)),
            TodoItem(
                title: "Review Chap 2.8 notes", isDone: true, created: now.addingTimeInterval(2),
                completed: now),
        ]
        let drops = await withCheckedContinuation { continuation in
            ChapDrop.recentFilesAsync(limit: DropPolicy.maxDockItems) {
                continuation.resume(returning: $0)
            }
        }
        ChapDrop.previewOverride = drops
        defer {
            ScreenshotShelf.previewOverride = nil
            NotchTodoView.previewItems = nil
            DownloadsShelf.previewOverride = nil
            DownloadsShelf.previewHoveredURL = nil
            ChapDrop.previewOverride = nil
            NotchFocusView.previewMode = nil
        }

        let variants: [(String, NotchPanelStyle, ColorScheme, Color, Bool)] = [
            ("notch-glass-light", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-empty-drop", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-focus-on", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-option", .glass, .light, Color(white: 0.92), true),
            ("notch-glass-light-collapsed", .glass, .light, Color(white: 0.92), false),
            ("notch-custom-collapsed", .custom, .dark, Color(white: 0.55), false),
            ("notch-guides-collapsed", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-download-hover", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-empty-shelves", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-todo", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-dark-todo", .glass, .dark, Color(white: 0.16), false),
            ("notch-glass-light-workspaces", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-light-timer", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-dark-timer-running", .glass, .dark, Color(white: 0.16), false),
            ("notch-glass-light-timer-focus-on", .glass, .light, Color(white: 0.92), false),
            ("notch-glass-dark-workspaces", .glass, .dark, Color(white: 0.16), false),
            ("notch-glass-dark", .glass, .dark, Color(white: 0.16), false),
            ("notch-custom", .custom, .dark, Color(white: 0.55), false),
        ]
        for (name, style, scheme, backdrop, optionHeld) in variants {
            // 빈 Drop 상태(상자만, 숫자 없음)도 한 장 그린다.
            ChapDrop.previewOverride = name.hasSuffix("empty-drop") ? [] : drops
            // 빈 선반: 두 선반을 비운 채 그린다 (안내 한 줄 + 좁아진 칸).
            let emptyShelves = name.hasSuffix("empty-shelves")
            ScreenshotShelf.previewOverride = emptyShelves ? [] : shots
            DownloadsShelf.previewOverride = emptyShelves ? [] : downloads
            // 마우스를 올린 것처럼 두 번째 다운로드의 전체 파일명 말풍선을 띄운다.
            DownloadsShelf.previewHoveredURL =
                name.hasSuffix("download-hover") && downloads.count > 1 ? downloads[1] : nil
            // 비동기로 채우는 이미지를 그리기 직전에 캐시에 넣는다 (NSCache는 언제든 비울 수 있다).
            for site in config.sites where site.launchType == .app {
                if let path = site.appPath { _ = await AppIconLoader.icon(forAppPath: path) }
            }
            for url in shots { _ = await ThumbnailLoader.image(for: url, maxPixelSize: 96) }
            for window in previewWorkspaces.flatMap(\.windows) {
                _ = await AppIconLoader.icon(forAppPath: window.applicationPath)
            }
            // 캐시가 비워질 수 있으니 그리기 직전에 한 번 더 채운다.
            for site in config.sites where site.launchType == .app {
                if let path = site.appPath { _ = await AppIconLoader.icon(forAppPath: path) }
            }
            let reveal = NotchRevealModel()
            reveal.revealed = true
            reveal.isOptionHeld = optionHeld
            reveal.collapsedWidgets =
                name.hasSuffix("-collapsed") ? [.screenshots, .downloads] : []
            NotchTodoView.previewHoveredIndex = name == "notch-glass-light-todo" ? 1 : nil
            // Focus 칸은 이름에 "-timer"가 있으면 Timer 모드로 그린다.
            NotchFocusView.previewMode = name.contains("-timer") ? .timer : .focus
            reveal.bottomOpacity = config.notchPanelOpacity
            reveal.colorHex = config.notchPanelColorHex
            let panel = NotchLauncherPanelView(
                minWidth: NotchLauncherPolicy.dockMinWidth(notchWidth: 185), topInset: 32,
                stripPlateauHalfWidth: 92.5 + 110,
                awakeSessionEnd: name.hasSuffix("focus-on")
                    ? Date().addingTimeInterval(3 * 3600 + 25 * 60) : nil, style: style,
                glassMaterial: config.notchGlassMaterial,
                slots: name.hasSuffix("-todo")
                    ? todoSlots
                    : name.hasSuffix("-workspaces")
                        ? workspaceSlots : previewSlots,
                showsMirror: config.notchMirrorEnabled,
                showsNote: config.notchQuickNoteEnabled,
                showsCoverScreens: config.notchCoverScreensEnabled, onLaunch: { _ in },
                timerEndProvider: {
                    name.hasSuffix("timer-running") ? Date().addingTimeInterval(18 * 60 + 42) : nil
                },
                showsShoulderGuides: name.hasPrefix("notch-guides"),
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

    @Test(
        "render the Workspace capture window",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderWorkspaceCapture() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        // 모니터 하나(디스플레이 이름만)와 둘(디스플레이 메뉴)을 모두 그린다.
        for (name, displays) in [
            (
                "workspace-capture",
                [
                    WorkspaceDisplay(identifier: "DISPLAY-1", name: "Built-in Retina Display")
                ]
            ),
            (
                "workspace-capture-displays",
                [
                    WorkspaceDisplay(identifier: "DISPLAY-1", name: "Built-in Retina Display"),
                    WorkspaceDisplay(identifier: "DISPLAY-2", name: "LG UltraFine"),
                ]
            ),
        ] {
            let model = WorkspaceCaptureViewModel()
            model.displays = displays
            model.finishLoading(Self.previewWorkspaces[0].windows)
            if displays.count > 1, let terminal = model.candidates.last {
                model.setDisplay(displays[1], for: terminal.id)
            }
            model.name = "Deep Work"
            let view = WorkspaceCaptureView(model: model, onCancel: {}, onSave: { _, _ in })
                .environment(\.colorScheme, .light)
            try Self.renderPNG(view).write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    @Test(
        "render the Workspaces settings panel",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderWorkspaceSettings() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapWorkspaceRender-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let library = WorkspaceLibrary(
            store: WorkspaceStore(fileURL: storeDirectory.appendingPathComponent("Workspaces.json"))
        )
        let displays = [
            WorkspaceDisplay(identifier: "DISPLAY-1", name: "Built-in Retina Display"),
            WorkspaceDisplay(identifier: "DISPLAY-2", name: "LG UltraFine"),
        ]
        var windows = Self.previewWorkspaces[0].windows
        windows[windows.count - 1] = windows[windows.count - 1].assigned(to: displays[1])
        let id = try #require(library.add(name: "Deep Work", windows: windows))
        for (name, scheme) in [
            ("settings-workspace-light", ColorScheme.light), ("settings-workspace-dark", .dark),
        ] {
            let view = WorkspaceDetailView(
                library: library, workspaceID: id, displays: displays,
                actions: WorkspaceSettingsActions()
            )
            .frame(width: 570, height: 640)
            .background(DS.surfaceBg)
            .environment(\.colorScheme, scheme)
            try Self.renderPNG(view).write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// 접힌 노치 왼쪽 타이머 배지를 하드웨어 노치(검정) 옆에 그린다.
    @Test("render the collapsed timer badge", .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderTimerBadge() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let notch = CGRect(x: 0, y: 0, width: 185, height: 32)
        let frame = NotchLauncherPolicy.timerBadgeFrame(notchRect: notch)
        for (name, remaining) in [
            ("notch-timer-badge", 18.0 * 60 + 42), ("notch-timer-badge-last", 42.0),
        ] {
            let view = ZStack(alignment: .topLeading) {
                Color(white: 0.85)
                // 하드웨어 노치 자리
                UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                    .fill(Color.black)
                    .frame(width: notch.width, height: notch.height)
                    .offset(x: frame.width - NotchLauncherPolicy.dropBadgeNotchOverlap)
                NotchTimerBadgeView(endDate: Date().addingTimeInterval(remaining))
                    .frame(width: frame.width, height: frame.height)
            }
            .frame(width: frame.width + notch.width, height: 48)
            try Self.renderPNG(view).write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// 닫히는 검정 띠 위로 타이머 배지를 먼저 올린 중간 프레임. 배지가
    /// 띠에서 끊겨 튀어나오지 않고 노치 왼쪽으로 자연스럽게 이어지는지 본다.
    @Test(
        "render the timer badge joined to the closing strip",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderTimerBadgeClosingTransition() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let dockWidth: CGFloat = 640
        let notch = CGRect(x: (dockWidth - 185) / 2, y: 0, width: 185, height: 32)
        let badge = NotchLauncherPolicy.timerBadgeFrame(notchRect: notch)
        let view = ZStack(alignment: .topLeading) {
            Color(white: 0.85)
            PressedStripShape(
                plateauHalfWidth: notch.width / 2 + NotchGeometry.stripPlateauSideWidth,
                centerDepth: notch.height,
                edgeDepth: 0
            )
            .fill(Color.black)
            .frame(width: dockWidth, height: 48)
            NotchTimerBadgeView(endDate: Date().addingTimeInterval(18 * 60 + 42))
                .frame(width: badge.width, height: badge.height)
                .offset(x: badge.minX, y: badge.minY)
        }
        .frame(width: dockWidth, height: 64)
        try Self.renderPNG(view).write(
            to: directory.appendingPathComponent("notch-timer-badge-closing.png"))
    }

    /// 실제 메모 파일을 읽지 않는 고정 문구로 Quick Note의 불투명 custom card를 확인한다.
    @Test(
        "render the custom Quick Note window chrome",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderQuickNoteWindowChrome() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        for (name, scheme, backdrop) in [
            ("quick-note-window-light", ColorScheme.light, Color(white: 0.92)),
            ("quick-note-window-dark", ColorScheme.dark, Color(white: 0.16)),
        ] {
            let view = QuickNoteWindowContent(
                previewText: "Draft the launch notes before the stand-up.",
                onClose: {}
            )
            .frame(width: 420, height: 320)
            .background(backdrop)
            .environment(\.colorScheme, scheme)
            try Self.renderPNG(view).write(
                to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// Tools가 보유한 ⌥N을 런처에 넣으려 할 때, 입력이 거부되고 빨간 안내가 보이는지 그린다.
    @Test(
        "render the launcher shortcut conflict",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderLauncherShortcutConflict() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        for (name, scheme) in [
            ("settings-launcher-shortcut-conflict-light", ColorScheme.light),
            ("settings-launcher-shortcut-conflict-dark", ColorScheme.dark),
        ] {
            let view = LauncherShortcutConflictPreview()
                .frame(width: 560, height: 440)
                .background(DS.surfaceBg)
                .environment(\.colorScheme, scheme)
            try Self.renderPNG(view).write(
                to: directory.appendingPathComponent("\(name).png"))
        }
    }

    private struct LauncherShortcutConflictPreview: View {
        @State private var site = Site(
            name: "Docs", url: "https://docs.example.com", width: 900, height: 700,
            shortcut: "N")
        @State private var isEditing = true

        var body: some View {
            SiteConfigView(
                site: $site,
                isEditing: $isEditing,
                quickNoteShortcut: "N",
                coverScreensShortcut: "L"
            )
        }
    }

    private static var previewWorkspaces: [ChapWorkspace] {
        let windows = [
            WorkspaceWindow(
                applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
                applicationPath: "/Applications/Xcode.app", windowTitle: "Chap",
                displayIdentifier: "DISPLAY-1", displayName: "Built-in Retina Display",
                frame: WorkspaceFrame(left: 0.03, top: 0.05, width: 0.62, height: 0.88)),
            WorkspaceWindow(
                applicationName: "Safari", bundleIdentifier: "com.apple.Safari",
                applicationPath: "/Applications/Safari.app", windowTitle: "Documentation",
                displayIdentifier: "DISPLAY-1", displayName: "Built-in Retina Display",
                frame: WorkspaceFrame(left: 0.66, top: 0.05, width: 0.31, height: 0.55)),
            WorkspaceWindow(
                applicationName: "Terminal", bundleIdentifier: "com.apple.Terminal",
                applicationPath: "/System/Applications/Utilities/Terminal.app",
                windowTitle: "chap", displayIdentifier: "DISPLAY-1",
                displayName: "Built-in Retina Display",
                frame: WorkspaceFrame(left: 0.66, top: 0.62, width: 0.31, height: 0.31)),
            // 화면 오른쪽 끝·위아래에 꽉 붙은 창: 미니맵 테두리가 겹치지 않는지 본다.
            WorkspaceWindow(
                applicationName: "Notes", bundleIdentifier: "com.apple.Notes",
                applicationPath: "/System/Applications/Notes.app", windowTitle: "Notes",
                displayIdentifier: "DISPLAY-1", displayName: "Built-in Retina Display",
                frame: WorkspaceFrame(left: 0.5, top: 0, width: 0.5, height: 1)),
        ]
        return [
            ChapWorkspace(name: "Deep Work", windows: windows),
            ChapWorkspace(name: "Writing", windows: Array(windows.prefix(2))),
            ChapWorkspace(name: "Meeting", windows: Array(windows.suffix(3))),
        ]
    }

    /// Settings → Notch 화면을 그린다 (라이트·다크). 노치가 없는 Mac에서도 세부 설정까지 보이도록
    /// `previewForcesNotch`를 켠다.
    @Test("render the Notch settings", .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderNotchSettings() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default
        NotchSettingsView.previewForcesNotch = true
        defer { NotchSettingsView.previewForcesNotch = false }
        for (name, scheme) in [
            ("settings-notch-light", ColorScheme.light), ("settings-notch-dark", .dark),
        ] {
            var forced = config
            forced.notchLauncherEnabled = true
            let vm = SettingsViewModel(config: forced)
            let view = NotchSettingsView(vm: vm, onSave: {})
                .frame(width: 600, height: 720)
                .environment(\.colorScheme, scheme)
            let png = try Self.renderPNG(view)
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// Keep Awake 중앙 HUD(켜짐·꺼짐) 모습을 PNG로 남긴다. 물범이 파란 타일 위에서 읽히는지 본다.
    @Test(
        "render the Keep Awake HUD", .enabled(if: NotchRenderTool.outputDirectory != nil))
    @MainActor
    func renderKeepAwakeHUD() throws {
        let directory = URL(fileURLWithPath: try #require(NotchRenderTool.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, focusOn, message) in [
            ("hud-focus-on", true, "Keep Awake · 4 Hours"),
            ("hud-focus-off", false, "Keep Awake Off"),
        ] {
            let view = KeepAwakeHUD.makeContentView(message: message, focusOn: focusOn)
            let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)
            let png = try #require(rep.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// Settings → General 화면(Cover Screens 단축키 줄 포함)을 그린다.
    @Test("render the General settings", .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderGeneralSettings() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default
        let vm = SettingsViewModel(
            sites: config.sites, coverScreensShortcut: config.coverScreensShortcut)
        let view = GeneralSettingsView(vm: vm, updateController: UpdateController(), onSave: {})
            .frame(width: 600, height: 720)
            .environment(\.colorScheme, .light)
        try Self.renderPNG(view).write(to: directory.appendingPathComponent("settings-general.png"))
    }

    /// 메뉴 막대의 물범 아이콘을 밝은·어두운 막대 위에서 크게 그린다. 템플릿 이미지라 macOS가 하듯
    /// 밝은 막대에는 검정, 어두운 막대에는 흰색으로 칠해 본다.
    @Test("render the seal status bar icon", .enabled(if: NotchRenderTool.outputDirectory != nil))
    @MainActor
    func renderSealStatusIcon() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let template = AppDelegate.sealStatusBarImage()
        #expect(template.isTemplate)
        // 실제 메뉴 막대처럼 Retina(2배)로 한 번 그린 뒤, 그 픽셀을 그대로 크게 늘려 보여 준다.
        let retina = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(template.size.width) * 2,
                pixelsHigh: Int(template.size.height) * 2, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0))
        retina.size = template.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: retina)
        template.draw(in: NSRect(origin: .zero, size: template.size))
        NSGraphicsContext.restoreGraphicsState()
        let icon = NSImage(size: template.size)
        icon.addRepresentation(retina)
        let scale: CGFloat = 8
        let size = NSSize(
            width: 2 * icon.size.width * scale + 3 * 16, height: icon.size.height * scale + 32)
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .none
        for (index, (bar, ink)) in [
            (NSColor(white: 0.93, alpha: 1), NSColor.black),
            (NSColor(white: 0.12, alpha: 1), NSColor.white),
        ].enumerated() {
            let x = 16 + CGFloat(index) * (icon.size.width * scale + 16)
            let frame = NSRect(
                x: x, y: 16, width: icon.size.width * scale, height: icon.size.height * scale)
            bar.setFill()
            frame.insetBy(dx: -8, dy: -8).fill()
            // 템플릿을 한 색으로 칠한다: 이미지 모양을 마스크로 쓰고 그 위를 잉크로 덮는다.
            let tinted = NSImage(size: icon.size, flipped: false) { rect in
                icon.draw(in: rect)
                ink.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: frame)
        }
        NSGraphicsContext.restoreGraphicsState()
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("status-seal.png"))
    }

    /// 보조 화면 가림막(꼬리를 까딱하는 물범)을 그려 남긴다.
    @Test("render the companion seal", .enabled(if: NotchRenderTool.outputDirectory != nil))
    @MainActor
    func renderCompanion() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let view = CoverScreensCompanionView().frame(width: 1600, height: 900)
        try Self.renderPNG(view).write(to: directory.appendingPathComponent("cover-companion.png"))
    }

    /// Settings → Tools 화면을 그린다.
    @Test("render the Tools settings", .enabled(if: NotchRenderTool.outputDirectory != nil))
    func renderToolsSettings() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default
        let vm = SettingsViewModel(
            sites: config.sites, notchQuickNoteShortcut: config.notchQuickNoteShortcut,
            coverScreensShortcut: config.coverScreensShortcut)
        let view = ToolsSettingsView(vm: vm, onSave: {})
            .frame(width: 600, height: 760)
            .environment(\.colorScheme, .light)
        try Self.renderPNG(view).write(to: directory.appendingPathComponent("settings-tools.png"))
    }

    /// Cover Screens 가림막 모습을 PNG로 남긴다. 검정 위에서 물범·시간·안내가 읽히는지 본다.
    @Test("render the Cover Screens cover", .enabled(if: NotchRenderTool.outputDirectory != nil))
    @MainActor
    func renderCoverScreens() throws {
        let directory = URL(fileURLWithPath: try #require(NotchRenderTool.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let view = CoverScreensView(
            showsClock: true, hint: CoverScreensPolicy.hint, message: "Back in 10 minutes"
        )
        .frame(width: 900, height: 560)
        let png = try Self.renderPNG(view)
        try png.write(to: directory.appendingPathComponent("cover-screens.png"))
    }

    /// 선반을 접고 펼 때 도커가 SwiftUI로 잰 크기를 컨트롤러에 알리는지 확인한다.
    /// 실제 앱처럼 창 안에 올린 뒤 접고, 보고된 폭이 줄었다 돌아오는지 본다.
    @Test(
        "folding shelves reports a narrower dock size and returns when unfolded",
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func collapseReportsSize() throws {
        let config = (try? ConfigStore().load(connectedDisplays: []).config) ?? .default
        // 여섯 칸을 모두 채워 도커가 최소 폭보다 넉넉히 넓게 만든다. 최소 폭에 걸리면 접어도 줄어들 수 없다.
        let slots = NotchSlotContent.slots(
            widgets: [.screenshots, .downloads, .sites, .apps, .folders, .todo],
            sites: config.sites)
        // 선반이 비면 Screenshots가 저절로 접혀 "펼친 상태"가 아니게 된다. 파일이 있는 상태로 고정한다.
        ScreenshotShelf.previewOverride = [URL(fileURLWithPath: "/tmp/chap-shot.png")]
        DownloadsShelf.previewOverride = [URL(fileURLWithPath: "/tmp/chap-download.pdf")]
        defer {
            ScreenshotShelf.previewOverride = nil
            DownloadsShelf.previewOverride = nil
        }
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
        reveal.collapsedWidgets = [.screenshots, .downloads]
        settle()
        let folded = try #require(reported.last)
        reveal.collapsedWidgets = []
        settle()
        let back = try #require(reported.last)

        #expect(folded.width < normal.width, "normal \(normal) folded \(folded)")
        #expect(back.width == normal.width, "normal \(normal) back \(back)")
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
        // 재현에는 Drop 파일이 하나 이상 필요하다. 비어 있으면 확인할 수 없으니 건너뛴다.
        guard hasDropFiles else { return }
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

    /// 도커가 열린 채 Keep Awake를 켜고 끄면 상단 띠 시계가 다시 열지 않아도 바뀌는지 확인한다.
    /// Focus 시계는 띠에서 뺐다(주석으로 남긴 `awakeStripClock`). 시계를 되살리면 이 테스트도 다시 켠다.
    @Test(
        "the strip Focus clock follows Keep Awake changes while the dock is open",
        .disabled("The Focus clock is no longer drawn on the strip"),
        .enabled(if: NotchRenderTool.outputDirectory != nil))
    func stripClockFollowsKeepAwake() async throws {
        let reveal = NotchRevealModel()
        reveal.revealed = true
        let panel = NotchLauncherPanelView(
            minWidth: NotchLauncherPolicy.dockMinWidth(notchWidth: 185), topInset: 32,
            stripPlateauHalfWidth: 92.5 + 110, awakeSessionEnd: nil, style: .custom,
            glassMaterial: .regular, slots: [], showsMirror: false, showsNote: false,
            onLaunch: { _ in }, reveal: reveal)
        let hosting = NSHostingView(rootView: panel)
        hosting.safeAreaRegions = []
        let size = hosting.fittingSize
        let window = NSWindow(
            contentRect: CGRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        let off = try Self.renderPNG(panel)
        NotificationCenter.default.post(
            name: KeepAwakeController.didChangeNotification,
            object: Date().addingTimeInterval(3600))
        try await Task.sleep(for: .milliseconds(300))
        hosting.layoutSubtreeIfNeeded()
        let on = try Self.bitmapPNG(of: hosting)
        NotificationCenter.default.post(
            name: KeepAwakeController.didChangeNotification, object: nil)
        try await Task.sleep(for: .milliseconds(300))
        let offAgain = try Self.bitmapPNG(of: hosting)
        #expect(on != off, "the clock should appear without reopening")
        #expect(offAgain != on, "the clock should disappear without reopening")
    }

    /// 이미 창에 올라간 hosting 뷰를 그대로 비트맵으로 그린다.
    static func bitmapPNG(of hosting: NSView) throws -> Data {
        hosting.displayIfNeeded()
        let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return try #require(rep.representation(using: .png, properties: [:]))
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
