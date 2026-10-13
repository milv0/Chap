import AppKit
import Foundation
import Testing

@testable import Chap

@Suite("Workspace geometry")
struct WorkspaceGeometryTests {
    @Test("captured bounds round-trip on the same display")
    func boundsRoundTrip() {
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 860)
        let bounds = (left: 72, top: 86, right: 936, bottom: 688)

        let frame = WorkspaceGeometry.capture(
            bounds: bounds, visibleFrame: visible, primaryHeight: 900)
        let restored = WorkspaceGeometry.bounds(
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

        let frame = WorkspaceGeometry.capture(
            bounds: bounds, visibleFrame: visible, primaryHeight: 900)
        let restored = WorkspaceGeometry.bounds(
            for: frame, visibleFrame: visible, primaryHeight: 900)

        #expect(restored.left == bounds.left)
        #expect(restored.top == bounds.top)
        #expect(restored.right == bounds.right)
        #expect(restored.bottom == bounds.bottom)
    }

    @Test("invalid saved fractions are clamped into the visible display")
    func clampsInvalidFractions() {
        let visible = CGRect(x: 100, y: 50, width: 1000, height: 700)
        let frame = WorkspaceFrame(left: -2, top: 5, width: 2, height: 0.01)

        let bounds = WorkspaceGeometry.bounds(
            for: frame, visibleFrame: visible, primaryHeight: 800)

        #expect(bounds.left == 100)
        #expect(bounds.top == 650)
        #expect(bounds.right == 1100)
        #expect(bounds.bottom == 750)
    }
}

@Suite("Workspace store")
struct WorkspaceStoreTests {
    private func window(_ name: String = "Preview") -> WorkspaceWindow {
        WorkspaceWindow(
            applicationName: name,
            bundleIdentifier: "com.example.\(name.lowercased())",
            applicationPath: "/Applications/\(name).app",
            windowTitle: name,
            displayIdentifier: "DISPLAY-1",
            displayName: "Built-in Display",
            frame: WorkspaceFrame(left: 0.1, top: 0.2, width: 0.6, height: 0.5))
    }

    @Test("workspace names are cleaned and empty captures are refused")
    func cleansNames() {
        #expect(WorkspaceStore.cleanedName("  Deep\nWork  ") == "Deep Work")
        #expect(WorkspaceStore.cleanedName("  \n ") == nil)
        #expect(WorkspaceStore.adding(name: "", windows: [window()], to: []).isEmpty)
        #expect(WorkspaceStore.adding(name: "Deep Work", windows: [], to: []).isEmpty)
    }

    @Test("adding caps workspaces and captured windows")
    func appliesLimits() {
        let windows = (0..<10).map { window("App \($0)") }
        var workspaces: [ChapWorkspace] = []
        for index in 0..<10 {
            workspaces = WorkspaceStore.adding(
                name: "Workspace \(index)", windows: windows, to: workspaces)
        }

        #expect(workspaces.count == WorkspaceStore.maxWorkspaces)
        #expect(workspaces.allSatisfy { $0.windows.count == WorkspaceStore.maxWindows })
    }

    @Test("Workspaces is available only in widget slots")
    func notchWidgetPlacement() {
        #expect(NotchWidget.workspaces.fits(slot: 2))
        #expect(!NotchWidget.workspaces.fits(slot: 0))
        let slots = NotchSlotContent.slots(
            widgets: [.none, .none, .workspaces], sites: [],
            workspaces: [ChapWorkspace(name: "Deep Work", windows: [window()])])
        #expect(slots.count == 1)
        guard case .workspaces(let workspaces) = slots.first else {
            Issue.record("Expected a Workspaces slot")
            return
        }
        #expect(workspaces.first?.name == "Deep Work")
    }

    @Test("workspaces round-trip through a local JSON file")
    func roundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapWorkspaceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WorkspaceStore(fileURL: directory.appendingPathComponent("Workspaces.json"))
        #expect(store.load().isEmpty)
        let expected = WorkspaceStore.adding(name: "Deep Work", windows: [window()], to: [])

        try store.save(expected)
        let loaded = store.load()

        #expect(loaded == expected)
    }

    @Test("an unreadable workspace file is preserved before a new save")
    func preservesUnreadableFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ChapWorkspaceCorruptTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("Workspaces.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = WorkspaceStore(fileURL: fileURL)

        #expect(store.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        let backups = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        #expect(backups.contains { $0.lastPathComponent.hasPrefix("Workspaces.unreadable-") })

        let expected = WorkspaceStore.adding(name: "Recovered", windows: [window()], to: [])
        try store.save(expected)
        #expect(store.load() == expected)
    }

    @Test("an unreadable file is never overwritten when preservation fails")
    func refusesUnreadableOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ChapWorkspaceLockedTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("Workspaces.json")
        let original = Data("still-not-json".utf8)
        try original.write(to: fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = WorkspaceStore(fileURL: fileURL)

        #expect(store.load().isEmpty)
        #expect(throws: WorkspaceStoreError.unreadableExistingFile) {
            try store.save([])
        }
        #expect(try Data(contentsOf: fileURL) == original)
    }
}

@Suite("Workspace display choice")
struct WorkspaceDisplayChoiceTests {
    private let window = WorkspaceWindow(
        applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
        applicationPath: "/Applications/Xcode.app", windowTitle: "Chap",
        displayIdentifier: "BUILT-IN", displayName: "Built-in Retina Display",
        frame: WorkspaceFrame(left: 0.1, top: 0.2, width: 0.6, height: 0.7))

    @Test("moving a window to another display keeps its relative frame")
    func movesToDisplay() {
        let moved = window.assigned(
            to: WorkspaceDisplay(identifier: "LG-1", name: "LG UltraFine"))

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
            WorkspaceDisplay(identifier: "A", name: "Built-in Retina Display"),
            WorkspaceDisplay(identifier: "B", name: "LG UltraFine"),
            WorkspaceDisplay(identifier: "C", name: "LG UltraFine"),
        ]

        #expect(
            WorkspaceDisplay.menuLabels(for: displays) == [
                "Built-in Retina Display", "LG UltraFine 1", "LG UltraFine 2",
            ])
    }

    @Test("the capture model changes one window's display and saves it")
    func captureModelChangesDisplay() {
        let model = WorkspaceCaptureViewModel()
        model.finishLoading([window])
        let external = WorkspaceDisplay(identifier: "LG-1", name: "LG UltraFine")

        model.setDisplay(external, for: window.id)

        #expect(model.selectedWindows.first?.display == external)
        #expect(model.selectedWindows.first?.frame == window.frame)
    }
}

@Suite("Workspace editing")
struct WorkspaceEditingTests {
    private func window(_ name: String) -> WorkspaceWindow {
        WorkspaceWindow(
            applicationName: name, bundleIdentifier: "com.example.\(name)",
            applicationPath: "/Applications/\(name).app",
            frame: WorkspaceFrame(left: 0, top: 0, width: 0.5, height: 0.5))
    }

    @Test("editing keeps the workspace's place and id, and takes the new name and windows")
    func replaces() throws {
        let first = ChapWorkspace(name: "Deep Work", windows: [window("A"), window("B")])
        let second = ChapWorkspace(name: "Meeting", windows: [window("C")])

        let edited = WorkspaceStore.replacing(
            first.id, name: "  Focus  ", windows: [window("B")], in: [first, second])

        #expect(edited.map(\.name) == ["Focus", "Meeting"])
        #expect(edited.first?.id == first.id)
        #expect(edited.first?.windows.map(\.applicationName) == ["B"])
    }

    @Test("an edit with no name or no windows changes nothing")
    func refusesEmpty() {
        let workspace = ChapWorkspace(name: "Deep Work", windows: [window("A")])

        #expect(
            WorkspaceStore.replacing(
                workspace.id, name: " ", windows: [window("A")], in: [workspace])
                == [workspace])
        #expect(
            WorkspaceStore.replacing(workspace.id, name: "New", windows: [], in: [workspace])
                == [workspace])
    }
}

@Suite("Workspace position update")
struct WorkspacePositionUpdateTests {
    private func window(
        _ bundle: String, display: String = "A", left: Double = 0, title: String? = nil
    ) -> WorkspaceWindow {
        WorkspaceWindow(
            applicationName: bundle, bundleIdentifier: bundle,
            applicationPath: "/Applications/\(bundle).app", windowTitle: title,
            displayIdentifier: display, displayName: display,
            frame: WorkspaceFrame(left: left, top: 0, width: 0.5, height: 0.5))
    }

    @Test("windows take the new frame, display, and title of the same app; others stay put")
    func updatesMatchingApps() {
        let workspace = ChapWorkspace(
            name: "Deep Work", windows: [window("xcode"), window("notes", left: 0.2)])
        let captured = [window("xcode", display: "B", left: 0.4, title: "Chap"), window("mail")]

        let result = workspace.updatingPositions(from: captured)

        #expect(result.updated == 1)
        #expect(result.workspace.id == workspace.id)
        #expect(result.workspace.windows.map(\.bundleIdentifier) == ["xcode", "notes"])
        let xcode = result.workspace.windows[0]
        #expect(xcode.id == workspace.windows[0].id)
        #expect(xcode.frame.left == 0.4)
        #expect(xcode.displayIdentifier == "B")
        #expect(xcode.windowTitle == "Chap")
        #expect(result.workspace.windows[1] == workspace.windows[1])
    }
}
