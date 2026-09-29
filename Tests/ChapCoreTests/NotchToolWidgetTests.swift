import Foundation
import Testing

@testable import Chap

@Suite("Mirror widget")
struct MirrorPolicyTests {
    @Test(
        "camera access maps to what the mirror shows",
        arguments: [
            (CameraAccess.notDetermined, MirrorDisplayState.needsPermission),
            (.authorized, .live),
            (.denied, .denied),
            (.restricted, .restricted),
        ])
    func accessMapsToDisplayState(access: CameraAccess, expected: MirrorDisplayState) {
        #expect(MirrorPolicy.displayState(access: access, hasCamera: true) == expected)
    }

    @Test("no camera wins over any permission state")
    func noCameraWins() {
        for access in [CameraAccess.notDetermined, .authorized, .denied, .restricted] {
            #expect(MirrorPolicy.displayState(access: access, hasCamera: false) == .noCamera)
        }
    }

    @Test("capture runs only for a live mirror on the visible page of an open dock")
    func captureNeedsLiveVisibleOpen() {
        #expect(MirrorPolicy.shouldCapture(state: .live, isPageActive: true, isPanelOpen: true))
        #expect(!MirrorPolicy.shouldCapture(state: .live, isPageActive: false, isPanelOpen: true))
        #expect(!MirrorPolicy.shouldCapture(state: .live, isPageActive: true, isPanelOpen: false))
        #expect(
            !MirrorPolicy.shouldCapture(
                state: .needsPermission, isPageActive: true, isPanelOpen: true))
        #expect(!MirrorPolicy.shouldCapture(state: .denied, isPageActive: true, isPanelOpen: true))
    }
}

@Suite("Quick Note store")
struct QuickNoteStoreTests {
    private func makeStore() -> (QuickNoteStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChapQuickNoteTests-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("Nested/QuickNote.txt")
        return (QuickNoteStore(fileURL: file), directory)
    }

    @Test("a missing note loads as empty")
    func missingNoteIsEmpty() {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(store.load().isEmpty)
    }

    @Test("saving creates the folder and round-trips text, including emoji and Korean")
    func saveRoundTrips() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = "Call Min at 3 ☎️\n회의 자료 준비"

        try store.save(note)

        #expect(store.load() == note)
    }

    @Test("saving replaces the previous note")
    func saveReplaces() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try store.save("first")
        try store.save("")

        #expect(store.load().isEmpty)
    }

    @Test("notes longer than the limit are trimmed")
    func longNotesAreTrimmed() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let long = String(repeating: "a", count: QuickNoteStore.maxLength + 50)

        let saved = try store.save(long)

        #expect(saved.count == QuickNoteStore.maxLength)
        #expect(store.load().count == QuickNoteStore.maxLength)
    }

    @Test("the default note lives in Chap's Application Support folder")
    func defaultLocation() {
        let path = QuickNoteStore.defaultFileURL.path
        #expect(path.hasSuffix("Application Support/Chap/QuickNote.txt"))
    }
}

@Suite("Mirror and Quick Note widgets")
struct NotchToolWidgetDecodingTests {
    @Test("mirror and note widgets decode and round-trip")
    func toolWidgetsRoundTrip() throws {
        let json = #"{"notchWidgets": ["mirror", "note", "sites"], "sites": []}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))

        #expect(Array(config.notchWidgets.prefix(3)) == [.mirror, .note, .sites])
        let decoded = try JSONDecoder().decode(
            Config.self, from: try JSONEncoder().encode(config))
        #expect(decoded.notchWidgets == config.notchWidgets)
    }

    @Test("tool widgets are not launcher sections")
    func toolWidgetsHaveNoLaunchType() {
        #expect(NotchWidget.mirror.launchType == nil)
        #expect(NotchWidget.note.launchType == nil)
    }
}
