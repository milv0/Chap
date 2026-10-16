import AppKit
import Foundation
import Testing

@testable import Chap

@Suite("Layout geometry")
struct LayoutGeometryTests {
    @Test("captured bounds round-trip on the same display")
    func boundsRoundTrip() {
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 860)
        let bounds = (left: 72, top: 86, right: 936, bottom: 688)

        let frame = LayoutGeometry.capture(
            bounds: bounds, visibleFrame: visible, primaryHeight: 900)
        let restored = LayoutGeometry.bounds(
            for: frame, visibleFrame: visible, primaryHeight: 900)

        #expect(restored.left == bounds.left)
        #expect(restored.top == bounds.top)
        #expect(restored.right == bounds.right)
        #expect(restored.bottom == bounds.bottom)
    }

    @Test("secondary-display top-left coordinates round-trip")
    func secondaryDisplayRoundTrip() {
        let visible = CGRect(x: 1440, y: 20, width: 1920, height: 1057)
        let bounds = (left: 1600, top: -100, right: 2500, bottom: 600)

        let frame = LayoutGeometry.capture(
            bounds: bounds, visibleFrame: visible, primaryHeight: 900)
        let restored = LayoutGeometry.bounds(
            for: frame, visibleFrame: visible, primaryHeight: 900)

        #expect(restored.left == bounds.left)
        #expect(restored.top == bounds.top)
        #expect(restored.right == bounds.right)
        #expect(restored.bottom == bounds.bottom)
    }

    @Test("invalid saved fractions are clamped into the visible display")
    func clampsInvalidFractions() {
        let visible = CGRect(x: 100, y: 50, width: 1000, height: 700)
        let frame = LayoutFrame(left: -2, top: 5, width: 2, height: 0.01)

        let bounds = LayoutGeometry.bounds(
            for: frame, visibleFrame: visible, primaryHeight: 800)

        #expect(bounds.left == 100)
        #expect(bounds.top == 650)
        #expect(bounds.right == 1100)
        #expect(bounds.bottom == 750)
    }
}

@Suite("Layout store")
struct LayoutStoreTests {
    private func window(_ name: String = "Preview") -> LayoutWindow {
        LayoutWindow(
            applicationName: name,
            bundleIdentifier: "com.example.\(name.lowercased())",
            applicationPath: "/Applications/\(name).app",
            windowTitle: name,
            displayIdentifier: "DISPLAY-1",
            displayName: "Built-in Display",
            frame: LayoutFrame(left: 0.1, top: 0.2, width: 0.6, height: 0.5))
    }

    @Test("layout names are cleaned and empty captures are refused")
    func cleansNames() {
        #expect(LayoutStore.cleanedName("  Deep\nWork  ") == "Deep Work")
        #expect(LayoutStore.cleanedName("  \n ") == nil)
        #expect(LayoutStore.adding(name: "", windows: [window()], to: []).isEmpty)
        #expect(LayoutStore.adding(name: "Deep Work", windows: [], to: []).isEmpty)
    }

    @Test("adding caps layouts and captured windows")
    func appliesLimits() {
        let windows = (0..<10).map { window("App \($0)") }
        var layouts: [ChapLayout] = []
        for index in 0..<10 {
            layouts = LayoutStore.adding(
                name: "Layout \(index)", windows: windows, to: layouts)
        }

        #expect(layouts.count == LayoutStore.maxLayouts)
        #expect(layouts.allSatisfy { $0.windows.count == LayoutStore.maxWindows })
    }

    @Test("Layouts is a tab of the Apps slot, shown even without apps")
    func notchWidgetPlacement() {
        #expect(NotchWidget.apps.fits(slot: 2))
        #expect(!NotchWidget.apps.fits(slot: 0))
        let slots = NotchSlotContent.slots(
            widgets: [.none, .none, .apps], sites: [],
            layouts: [ChapLayout(name: "Deep Work", windows: [window()])])
        #expect(slots.count == 1)
        guard case .apps(let apps, let layouts) = slots.first else {
            Issue.record("Expected an Apps slot")
            return
        }
        #expect(apps == nil)
        #expect(layouts.first?.name == "Deep Work")
    }

    @Test("layouts round-trip through a local JSON file")
    func roundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapLayoutTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LayoutStore(fileURL: directory.appendingPathComponent("Layouts.json"))
        #expect(store.load().isEmpty)
        let expected = LayoutStore.adding(name: "Deep Work", windows: [window()], to: [])

        try store.save(expected)
        let loaded = store.load()

        #expect(loaded == expected)
    }

    @Test("a 2.17 Workspaces.json moves to Layouts.json and keeps its layouts")
    func migratesLegacyFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapLayoutLegacyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyURL = directory.appendingPathComponent(LayoutStore.legacyFileName)
        let fileURL = directory.appendingPathComponent("Layouts.json")
        // 예전 이름의 파일에 같은 형식으로 저장해 둔다.
        let saved = LayoutStore.adding(name: "Deep Work", windows: [window()], to: [])
        try LayoutStore(fileURL: legacyURL).save(saved)

        let store = LayoutStore(fileURL: fileURL)
        #expect(store.load() == saved)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test("a Workspaces.json that can't be moved is still read in place")
    func readsLegacyFileInPlace() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapLayoutLegacyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyURL = directory.appendingPathComponent(LayoutStore.legacyFileName)
        let saved = LayoutStore.adding(name: "Deep Work", windows: [window()], to: [])
        try LayoutStore(fileURL: legacyURL).save(saved)
        // 폴더를 읽기 전용으로 두어 이름 바꾸기(이동)가 실패하게 한다.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = LayoutStore(fileURL: directory.appendingPathComponent("Layouts.json"))
        #expect(store.load() == saved)
        #expect(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test("an existing Layouts.json wins over a leftover Workspaces.json")
    func newFileWins() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapLayoutLegacyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyURL = directory.appendingPathComponent(LayoutStore.legacyFileName)
        let fileURL = directory.appendingPathComponent("Layouts.json")
        try LayoutStore(fileURL: legacyURL).save(
            LayoutStore.adding(name: "Old", windows: [window()], to: []))
        let current = LayoutStore.adding(name: "New", windows: [window()], to: [])
        try LayoutStore(fileURL: fileURL).save(current)

        #expect(LayoutStore(fileURL: fileURL).load() == current)
        // 남은 예전 파일은 건드리지 않는다.
        #expect(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test("an unreadable layout file is preserved before a new save")
    func preservesUnreadableFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ChapLayoutCorruptTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("Layouts.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = LayoutStore(fileURL: fileURL)

        #expect(store.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        let backups = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        #expect(backups.contains { $0.lastPathComponent.hasPrefix("Layouts.unreadable-") })

        let expected = LayoutStore.adding(name: "Recovered", windows: [window()], to: [])
        try store.save(expected)
        #expect(store.load() == expected)
    }

    @Test("an unreadable file is never overwritten when preservation fails")
    func refusesUnreadableOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ChapLayoutLockedTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("Layouts.json")
        let original = Data("still-not-json".utf8)
        try original.write(to: fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = LayoutStore(fileURL: fileURL)

        #expect(store.load().isEmpty)
        #expect(throws: LayoutStoreError.unreadableExistingFile) {
            try store.save([])
        }
        #expect(try Data(contentsOf: fileURL) == original)
    }
}

@Suite("Layout display choice")
struct LayoutDisplayChoiceTests {
    private let window = LayoutWindow(
        applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
        applicationPath: "/Applications/Xcode.app", windowTitle: "Chap",
        displayIdentifier: "BUILT-IN", displayName: "Built-in Retina Display",
        frame: LayoutFrame(left: 0.1, top: 0.2, width: 0.6, height: 0.7))

    @Test("moving a window to another display keeps its relative frame")
    func movesToDisplay() {
        let moved = window.assigned(
            to: LayoutDisplay(identifier: "LG-1", name: "LG UltraFine"))

        #expect(moved.displayIdentifier == "LG-1")
        #expect(moved.displayName == "LG UltraFine")
        #expect(moved.frame == window.frame)
        #expect(moved.id == window.id)
    }

    @Test("follow cursor clears the saved display")
    func followsCursor() {
        let moved = window.assigned(to: nil)

        #expect(moved.displayIdentifier == nil)
        #expect(moved.displayName == nil)
        #expect(moved.display == nil)
    }

    @Test("identical monitor names get a number so the menu can tell them apart")
    func disambiguatesNames() {
        let displays = [
            LayoutDisplay(identifier: "A", name: "Built-in Retina Display"),
            LayoutDisplay(identifier: "B", name: "LG UltraFine"),
            LayoutDisplay(identifier: "C", name: "LG UltraFine"),
        ]

        #expect(
            LayoutDisplay.menuLabels(for: displays) == [
                "Built-in Retina Display", "LG UltraFine 1", "LG UltraFine 2",
            ])
    }

    @Test("the capture model changes one window's display and saves it")
    func captureModelChangesDisplay() {
        let model = LayoutCaptureViewModel()
        model.finishLoading([window])
        let external = LayoutDisplay(identifier: "LG-1", name: "LG UltraFine")

        model.setDisplay(external, for: window.id)

        #expect(model.selectedWindows.first?.display == external)
        #expect(model.selectedWindows.first?.frame == window.frame)
    }
}

@Suite("Layout editing")
struct LayoutEditingTests {
    private func window(_ name: String) -> LayoutWindow {
        LayoutWindow(
            applicationName: name, bundleIdentifier: "com.example.\(name)",
            applicationPath: "/Applications/\(name).app",
            frame: LayoutFrame(left: 0, top: 0, width: 0.5, height: 0.5))
    }

    @Test("editing keeps the layout's place and id, and takes the new name and windows")
    func replaces() throws {
        let first = ChapLayout(name: "Deep Work", windows: [window("A"), window("B")])
        let second = ChapLayout(name: "Meeting", windows: [window("C")])

        let edited = LayoutStore.replacing(
            first.id, name: "  Focus  ", windows: [window("B")], in: [first, second])

        #expect(edited.map(\.name) == ["Focus", "Meeting"])
        #expect(edited.first?.id == first.id)
        #expect(edited.first?.windows.map(\.applicationName) == ["B"])
    }

    @Test("an edit with no name or no windows changes nothing")
    func refusesEmpty() {
        let layout = ChapLayout(name: "Deep Work", windows: [window("A")])

        #expect(
            LayoutStore.replacing(
                layout.id, name: " ", windows: [window("A")], in: [layout])
                == [layout])
        #expect(
            LayoutStore.replacing(layout.id, name: "New", windows: [], in: [layout])
                == [layout])
    }
}

@Suite("Layout position update")
struct LayoutPositionUpdateTests {
    private func window(
        _ bundle: String, display: String = "A", left: Double = 0, title: String? = nil
    ) -> LayoutWindow {
        LayoutWindow(
            applicationName: bundle, bundleIdentifier: bundle,
            applicationPath: "/Applications/\(bundle).app", windowTitle: title,
            displayIdentifier: display, displayName: display,
            frame: LayoutFrame(left: left, top: 0, width: 0.5, height: 0.5))
    }

    @Test("windows take the new frame, display, and title of the same app; others stay put")
    func updatesMatchingApps() {
        let layout = ChapLayout(
            name: "Deep Work", windows: [window("xcode"), window("notes", left: 0.2)])
        let captured = [window("xcode", display: "B", left: 0.4, title: "Chap"), window("mail")]

        let result = layout.updatingPositions(from: captured)

        #expect(result.updated == 1)
        #expect(result.layout.id == layout.id)
        #expect(result.layout.windows.map(\.bundleIdentifier) == ["xcode", "notes"])
        let xcode = result.layout.windows[0]
        #expect(xcode.id == layout.windows[0].id)
        #expect(xcode.frame.left == 0.4)
        #expect(xcode.displayIdentifier == "B")
        #expect(xcode.windowTitle == "Chap")
        #expect(result.layout.windows[1] == layout.windows[1])
    }
}

@Suite("Layout display labels")
struct LayoutDisplayLabelTests {
    private let displays = [
        LayoutDisplay(identifier: "A", name: "Built-in Retina Display"),
        LayoutDisplay(identifier: "B", name: "LG UltraFine"),
        LayoutDisplay(identifier: "C", name: "LG UltraFine"),
    ]

    @Test("a connected display uses its menu label; a missing one is marked")
    func labels() {
        #expect(LayoutDisplay.label(for: nil, among: displays) == "Follow Cursor")
        #expect(
            LayoutDisplay.label(
                for: LayoutDisplay(identifier: "C", name: "LG UltraFine"), among: displays)
                == "LG UltraFine 2")
        #expect(
            LayoutDisplay.label(
                for: LayoutDisplay(identifier: "Z", name: "Studio Display"), among: displays)
                == "Studio Display (not connected)")
    }

    @Test("displays without a UUID still match by name")
    func matchesByName() {
        let unnamed = [LayoutDisplay(identifier: nil, name: "Only")]
        #expect(
            LayoutDisplay(identifier: nil, name: "Only").matches(unnamed[0]))
        #expect(
            !LayoutDisplay(identifier: nil, name: "Other").matches(unnamed[0]))
        #expect(
            !LayoutDisplay(identifier: "A", name: "Only").matches(unnamed[0]))
    }

    @Test("update positions keeps Follow Cursor but takes the new frame")
    func keepsFollowCursor() {
        let window = LayoutWindow(
            applicationName: "Mail", bundleIdentifier: "mail", applicationPath: "/A/Mail.app",
            frame: LayoutFrame(left: 0, top: 0, width: 0.5, height: 0.5))
        let layout = ChapLayout(name: "W", windows: [window])
        let captured = LayoutWindow(
            applicationName: "Mail", bundleIdentifier: "mail", applicationPath: "/A/Mail.app",
            displayIdentifier: "A", displayName: "Built-in",
            frame: LayoutFrame(left: 0.3, top: 0.3, width: 0.4, height: 0.4))

        let result = layout.updatingPositions(from: [captured])

        #expect(result.layout.windows[0].display == nil)
        #expect(result.layout.windows[0].frame.left == 0.3)
    }

    @Test("a restored frame grown to an app's minimum size stays inside the display")
    func clampsGrownBounds() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 700)
        // 오른쪽 아래 끝에 붙은 작은 창
        let frame = LayoutFrame(left: 0.9, top: 0.9, width: 0.1, height: 0.1)

        let bounds = LayoutGeometry.bounds(
            for: frame, visibleFrame: visible, primaryHeight: 700,
            minimumSize: CGSize(width: 400, height: 300))

        #expect(bounds.right - bounds.left == 400)
        #expect(bounds.bottom - bounds.top == 300)
        #expect(bounds.right <= 1000 && bounds.bottom <= 700)
        #expect(bounds.left == 600 && bounds.top == 400)
    }
}
