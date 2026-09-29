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

    @Test("capture runs only for a turned-on live mirror in an open dock")
    func captureNeedsLiveOnVisibleOpen() {
        func capture(
            _ state: MirrorDisplayState, on: Bool = true, open: Bool = true
        ) -> Bool {
            MirrorPolicy.shouldCapture(state: state, isTurnedOn: on, isPanelOpen: open)
        }
        #expect(capture(.live))
        #expect(!capture(.live, on: false))
        #expect(!capture(.live, open: false))
        #expect(!capture(.needsPermission))
        #expect(!capture(.denied))
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

    @Test("saved label reads just now, then a short relative time")
    func savedLabel() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(QuickNoteStore.savedLabel(for: nil, now: now) == nil)
        #expect(
            QuickNoteStore.savedLabel(for: now.addingTimeInterval(-20), now: now)
                == "Saved just now")
        let tenMinutes = QuickNoteStore.savedLabel(for: now.addingTimeInterval(-600), now: now)
        #expect(tenMinutes?.hasPrefix("Saved 10 min") == true)
        #expect(tenMinutes?.hasSuffix("ago") == true)
    }

    @Test("a saved note reports its save date")
    func lastSavedDate() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(store.lastSavedDate() == nil)

        try store.save("hello")

        let date = try #require(store.lastSavedDate())
        #expect(abs(date.timeIntervalSinceNow) < 60)
    }

    @Test("the default note lives in Chap's Application Support folder")
    func defaultLocation() {
        let path = QuickNoteStore.defaultFileURL.path
        #expect(path.hasSuffix("Application Support/Chap/QuickNote.txt"))
    }
}

@Suite("Mirror and Quick Note widgets")
struct NotchToolWidgetDecodingTests {
    @Test("a former Mirror slot is removed and later widgets move up")
    func formerMirrorSlotIsRemoved() throws {
        let json = #"{"notchWidgets": ["mirror", "note", "sites"], "sites": []}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))

        #expect(Array(config.notchWidgets.prefix(2)) == [.note, .sites])
        #expect(!config.notchWidgets.map(\.rawValue).contains("mirror"))
        #expect(config.notchMirrorEnabled)
    }

    @Test("the Mirror toggle defaults on and round-trips")
    func mirrorToggleRoundTrips() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.notchMirrorEnabled)

        let off = Config(notchMirrorEnabled: false, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: try JSONEncoder().encode(off))
        #expect(!decoded.notchMirrorEnabled)
    }

    @Test("Quick Note is not a launcher section")
    func noteHasNoLaunchType() {
        #expect(NotchWidget.note.launchType == nil)
    }
}
