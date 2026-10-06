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

    @Test("saved label shows Saved and when: time today, date this year, full date otherwise")
    func savedLabel() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 18, minute: 30))
        )
        func label(_ date: Date?) -> String? {
            QuickNoteStore.savedLabel(for: date, now: now, calendar: calendar, timeZone: utc)
        }
        #expect(label(nil) == nil)
        #expect(label(now.addingTimeInterval(-18 * 60)) == "Saved · 6:12 PM")
        #expect(label(now.addingTimeInterval(-2 * 86400)) == "Saved · Oct 4, 6:30 PM")
        #expect(label(now.addingTimeInterval(-400 * 86400)) == "Saved · Sep 1, 2025, 6:30 PM")
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

    @Test("the character count reads naturally and shows the limit near the cap")
    func characterCount() {
        #expect(QuickNoteStore.characterCountLabel(0) == "0 chars")
        #expect(QuickNoteStore.characterCountLabel(1) == "1 char")
        #expect(QuickNoteStore.characterCountLabel(1234) == "1,234 chars")
        #expect(QuickNoteStore.characterCountLabel(17_999) == "17,999 chars")
        #expect(QuickNoteStore.characterCountLabel(18_000) == "18,000 / 20,000 chars")
    }

    @Test("the default note lives in Chap's Application Support folder")
    func defaultLocation() {
        let path = QuickNoteStore.defaultFileURL.path
        #expect(path.hasSuffix("Application Support/Chap/QuickNote.txt"))
    }
}

@Suite("Mirror and Quick Note widgets")
struct NotchToolWidgetDecodingTests {
    @Test("former Mirror and Quick Note slots are removed and later widgets move up")
    func formerToolSlotsAreRemoved() throws {
        let json = #"{"notchWidgets": ["mirror", "note", "sites", "apps"], "sites": []}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))

        #expect(config.notchWidgets == [.none, .none, .sites, .apps, .none, .none])
        #expect(config.notchMirrorEnabled)
        #expect(config.notchQuickNoteEnabled)
    }

    @Test("the Quick Note toggle defaults on and round-trips")
    func quickNoteToggleRoundTrips() throws {
        let off = Config(notchQuickNoteEnabled: false, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: try JSONEncoder().encode(off))
        #expect(!decoded.notchQuickNoteEnabled)
    }

    @Test("strip tools sit right after the Drop badge, or in its place when Drop is empty")
    func stripToolLayout() {
        let badge = NotchLauncherPolicy.dropBadgeIconCenterOffset
        let pitch = NotchLauncherPolicy.stripToolPitch
        #expect(
            NotchLauncherPolicy.stripToolCenterOffsets(besideDropBadge: false, count: 2)
                == [badge, badge + pitch])
        #expect(
            NotchLauncherPolicy.stripToolCenterOffsets(besideDropBadge: true, count: 2)
                == [badge + pitch, badge + 2 * pitch])
        // 모두 노치 오른쪽 상태 영역(110pt) 안에 들어간다.
        let last = NotchLauncherPolicy.stripToolCenterOffsets(besideDropBadge: true, count: 2).last!
        #expect(last + pitch / 2 <= NotchGeometry.stripPlateauSideWidth)
    }

    @Test("the Mirror toggle defaults on and round-trips")
    func mirrorToggleRoundTrips() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.notchMirrorEnabled)

        let off = Config(notchMirrorEnabled: false, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: try JSONEncoder().encode(off))
        #expect(!decoded.notchMirrorEnabled)
    }

    @Test("tool widgets are no longer placeable slots")
    func toolsAreNotSlots() {
        #expect(NotchWidget(rawValue: "note") == nil)
        #expect(NotchWidget(rawValue: "mirror") == nil)
    }
}

@Suite("Notch dock width")
struct NotchDockWidthTests {
    @Test("the dock never shrinks below 640pt or the notch plus both status areas")
    func minimumWidth() {
        #expect(NotchLauncherPolicy.dockMinWidth(notchWidth: 185) == 640)
        let wide = NotchLauncherPolicy.dockMinWidth(notchWidth: 520)
        #expect(wide == 820, "got \(wide)")
    }
}

@Suite("Strip popup dismissal")
struct StripPopupDismissalTests {
    let strip: CGFloat = 32
    var popup: CGRect { CGRect(x: 400, y: 40, width: 240, height: 128) }

    @Test("a click outside the open popup collapses it")
    func outsideCollapses() {
        #expect(
            NotchLauncherPolicy.shouldCollapseStripPopup(
                click: CGPoint(x: 100, y: 150), popupFrame: popup, stripHeight: strip))
    }

    @Test("clicks inside the popup or on the strip icons keep it open")
    func insideAndStripKeep() {
        #expect(
            !NotchLauncherPolicy.shouldCollapseStripPopup(
                click: CGPoint(x: 500, y: 100), popupFrame: popup, stripHeight: strip))
        #expect(
            !NotchLauncherPolicy.shouldCollapseStripPopup(
                click: CGPoint(x: 520, y: 16), popupFrame: popup, stripHeight: strip))
    }

    @Test("popups hang below the strip and stay 12pt inside the dock")
    func popupCenterClamps() {
        let size = CGSize(width: 240, height: 128)
        let normal = NotchLauncherPolicy.stripPopupCenter(
            iconCenterX: 400, popupSize: size, containerWidth: 900, stripHeight: strip)
        #expect(normal == CGPoint(x: 400, y: 32 + 8 + 64))
        let nearEdge = NotchLauncherPolicy.stripPopupCenter(
            iconCenterX: 880, popupSize: size, containerWidth: 900, stripHeight: strip)
        #expect(nearEdge.x == 768, "got \(nearEdge.x)")
    }
}
