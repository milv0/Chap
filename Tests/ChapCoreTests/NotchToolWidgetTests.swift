import AppKit
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

    @Test("closing the mirror invalidates a delayed camera start")
    func closingInvalidatesDelayedStart() {
        let intent = MirrorCaptureIntent()
        let first = intent.begin()
        #expect(intent.permits(first))

        intent.cancel()
        #expect(!intent.permits(first))

        let second = intent.begin()
        #expect(!intent.cancel(token: first))
        #expect(!intent.permits(first))
        #expect(intent.permits(second))
        #expect(intent.cancel(token: second))
        #expect(!intent.permits(second))
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

    @Test("a note that isn't text is moved to Backups instead of being treated as empty")
    func unreadableNoteIsPreserved() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let garbage = Data([0xFF, 0xFE, 0xFD, 0x00, 0xC3])
        try garbage.write(to: store.fileURL)

        let result = store.loadResult()

        guard case .preserved(let url) = result else {
            Issue.record("expected .preserved, got \(result)")
            return
        }
        #expect(url.deletingLastPathComponent() == store.backupDirectoryURL)
        #expect(url.lastPathComponent.hasPrefix("QuickNote.unreadable-"))
        #expect(try Data(contentsOf: url) == garbage)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        // 옮겨 둔 원본은 백업 개수에 세지 않아 정리되지 않는다.
        #expect(store.backupURLs().isEmpty)
    }

    @Test("a missing note and a readable note load as text")
    func readableResults() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(store.loadResult() == .text(""))

        try store.save("hello")

        #expect(store.loadResult() == .text("hello"))
    }

    @Test("the first overwrite backs up the previous note; empty notes are never backed up")
    func firstOverwriteBacksUp() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        try store.save("", now: now)
        try store.save("first", now: now)
        #expect(store.backupURLs().isEmpty)

        try store.save("second", now: now.addingTimeInterval(1))

        let backups = store.backupURLs()
        #expect(backups.count == 1)
        #expect(try String(contentsOf: backups[0], encoding: .utf8) == "first")
    }

    @Test("deleting most of a long note backs it up right away")
    func largeLossBacksUp() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let long = String(repeating: "meeting notes ", count: 10)

        try store.save("draft", now: now)
        try store.save(long, now: now.addingTimeInterval(1))  // 첫 백업: "draft"
        try store.save("", now: now.addingTimeInterval(2))  // 간격 안이지만 크게 줄었다

        let contents = try store.backupURLs().map { try String(contentsOf: $0, encoding: .utf8) }
        #expect(contents == ["draft", long])
        #expect(store.load().isEmpty)
    }

    @Test("old backups are pruned to the newest ten")
    func backupsArePruned() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        for index in 0...12 {
            try store.save(
                "note \(index)",
                now: start.addingTimeInterval(Double(index) * QuickNoteBackupPolicy.interval))
        }

        let contents = try store.backupURLs().map { try String(contentsOf: $0, encoding: .utf8) }
        #expect(contents.count == QuickNoteBackupPolicy.maxBackups)
        #expect(contents.first == "note 2")
        #expect(contents.last == "note 11")
    }

    @Test("backups are spaced out unless the note shrinks a lot")
    func backupPolicy() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recent = now.addingTimeInterval(-60)
        let old = now.addingTimeInterval(-QuickNoteBackupPolicy.interval)
        let long = String(repeating: "x", count: 100)
        func should(_ previous: String, _ next: String, _ last: Date?) -> Bool {
            QuickNoteBackupPolicy.shouldBackUp(
                previous: previous, next: next, lastBackup: last, now: now)
        }
        #expect(should("a", "ab", nil))
        #expect(!should("a", "ab", recent))
        #expect(should("a", "ab", old))
        #expect(!should("same", "same", nil))
        #expect(!should("  \n", "text", nil))
        #expect(should(long, "", recent))
        #expect(should(long, String(long.prefix(49)), recent))
        #expect(!should(long, String(long.prefix(60)), recent))
        // 짧은 메모는 지울 때마다 백업하지 않는다.
        #expect(!should("short note", "", recent))
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

        #expect(config.notchWidgets == [.none, .none, .launchers, .apps, .none, .none])
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

@Suite("Quick Note window placement")
struct QuickNotePlacementTests {
    // 1512×982 MacBook 화면, 노치 높이 38pt, 메뉴 막대 아래가 보이는 영역의 윗변.
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    var notch: CGRect { CGRect(x: 663, y: 944, width: 186, height: 38) }
    var visible: CGRect { CGRect(x: 0, y: 70, width: 1512, height: 874) }

    @Test("the window hangs from the notch, centered on it")
    func hangsFromNotch() {
        let origin = QuickNotePlacement.origin(
            windowSize: CGSize(width: 420, height: 348), notchRect: notch, visibleFrame: visible)
        #expect(origin == CGPoint(x: 546, y: 596))
        #expect(origin.y + 348 == notch.minY)
    }

    @Test("a window taller than the room left is kept on screen")
    func tallWindowStaysOnScreen() {
        let origin = QuickNotePlacement.origin(
            windowSize: CGSize(width: 420, height: 2000), notchRect: notch, visibleFrame: visible)
        #expect(origin.y == visible.minY)
    }

    @Test("a wide window is pulled back inside the screen edges")
    func wideWindowStaysInside() {
        let origin = QuickNotePlacement.origin(
            windowSize: CGSize(width: 1600, height: 300), notchRect: notch, visibleFrame: visible)
        #expect(origin.x == visible.minX)
    }
}

@Suite("Keep Awake HUD seal")
@MainActor
struct KeepAwakeHUDSealTests {
    /// 자고 깨는 두 모습에서 물범이 움직이면 HUD가 깜빡이는 것처럼 보인다. z 자리는 늘 비워 둔다.
    @Test("the seal keeps its place whether or not the z is drawn")
    func sealDoesNotMoveForTheZ() {
        let awake = ChapMascotImage.image(pixelSize: 4, eyes: .open, pose: .tailUp)
        let asleep = ChapMascotImage.image(
            pixelSize: 4, eyes: .closed, pose: .rest, showsSleepZ: true)

        #expect(awake.size == asleep.size)
        // 격자 12줄 + z 여백 4줄, 칸 4pt.
        #expect(awake.size == NSSize(width: 96, height: 64))
    }

    @Test("the z sits in the margin above the seal, not in the sprite rows")
    func zUsesTheMargin() {
        #expect(ChapMascotImage.sleepZRowSpan == ChapMascot.sleepZRows.count)
    }
}
