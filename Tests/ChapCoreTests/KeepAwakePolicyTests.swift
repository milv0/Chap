import Foundation
import Testing

@testable import Chap

@Suite("Keep Awake Policy")
struct KeepAwakePolicyTests {
    @Test("presets are 30m, 1h, 4h, 8h, and 12h in order")
    func presetsMatchSpecification() {
        let durations = KeepAwakePolicy.presets.map(\.duration)
        let expected: [TimeInterval] = [1800, 3600, 14400, 28800, 43200]

        #expect(durations == expected)
    }

    @Test(
        "remaining label rounds up to friendly units",
        arguments: [
            (1800.0, "30m"),
            (3600.0, "1h"),
            (14520.0, "4h 2m"),
            (30.0, "1m"),
            (0.0, "0m"),
            (-60.0, "0m"),
        ] as [(TimeInterval, String)])
    func remainingLabelFormats(remaining: TimeInterval, expected: String) {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let label = KeepAwakePolicy.remainingLabel(
            until: now.addingTimeInterval(remaining), now: now)

        #expect(label == expected)
    }

    @Test("menu title is plain when no session is active")
    func plainTitleWhenInactive() {
        let title = KeepAwakePolicy.menuTitle(sessionEnd: nil, now: Date())

        #expect(title == "Keep Mac Awake")
    }

    @Test("menu title appends remaining time during a session")
    func titleShowsRemainingDuringSession() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let title = KeepAwakePolicy.menuTitle(
            sessionEnd: now.addingTimeInterval(3600), now: now)

        #expect(title == "Keep Mac Awake — 1h left")
    }

    @Test("started HUD message names the preset")
    func startedHUDMessageNamesPreset() {
        let message = KeepAwakePolicy.hudMessage(startedPresetTitle: "4 Hours")

        #expect(message == "Keep Awake · 4 Hours")
    }

    @Test("ended HUD message is a fixed off label")
    func endedHUDMessageIsFixed() {
        #expect(KeepAwakePolicy.hudMessageEnded == "Keep Awake Off")
    }

    @Test("expired session end falls back to the plain title")
    func expiredSessionShowsPlainTitle() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let title = KeepAwakePolicy.menuTitle(
            sessionEnd: now.addingTimeInterval(-1), now: now)

        #expect(title == "Keep Mac Awake")
    }

    @Test("quit confirmation asks for explicit confirmation")
    func quitConfirmationCopy() {
        #expect(
            KeepAwakePolicy.quitConfirmationInfo
                == "Are you sure you want to quit Chap?")
    }

    @Test("clock label always stays in h:mm:ss form")
    func clockLabelForm() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        #expect(
            KeepAwakePolicy.remainingClockLabel(
                until: now.addingTimeInterval(45 * 60), now: now) == "0:45:00")
        #expect(
            KeepAwakePolicy.remainingClockLabel(
                until: now.addingTimeInterval(67 * 60 + 5), now: now) == "1:07:05")
        #expect(
            KeepAwakePolicy.remainingClockLabel(
                until: now.addingTimeInterval(12 * 60 * 60), now: now) == "12:00:00")
        #expect(
            KeepAwakePolicy.remainingClockLabel(
                until: now.addingTimeInterval(0.1), now: now) == "0:00:01")
        #expect(
            KeepAwakePolicy.remainingClockLabel(
                until: now.addingTimeInterval(-5), now: now) == "0:00:00")
    }

    @Test("no session is never expired")
    func missingSessionIsNotExpired() {
        #expect(!KeepAwakePolicy.isExpired(sessionEnd: nil, now: Date()))
    }

    @Test(
        "session expires at or after its wall-clock end",
        arguments: [
            (-1.0, true),
            (0.0, true),
            (1.0, false),
            (3600.0, false),
        ] as [(TimeInterval, Bool)])
    func expiryFollowsWallClock(secondsUntilEnd: TimeInterval, expired: Bool) {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let result = KeepAwakePolicy.isExpired(
            sessionEnd: now.addingTimeInterval(secondsUntilEnd), now: now)

        #expect(result == expired)
    }

    @Test("a 1 hour session is expired after an overnight lid close")
    func overnightSleepExpiresSession() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let end = start.addingTimeInterval(3600)
        let nextMorning = start.addingTimeInterval(10 * 3600)

        #expect(KeepAwakePolicy.isExpired(sessionEnd: end, now: nextMorning))
        #expect(KeepAwakePolicy.isLateExpiry(sessionEnd: end, now: nextMorning))
    }

    @Test(
        "only expiries noticed well after the end count as late",
        arguments: [
            (0.0, false),
            (1.0, false),
            (5.0, false),
            (6.0, true),
            (8 * 3600.0, true),
        ] as [(TimeInterval, Bool)])
    func lateExpiryUsesTolerance(secondsLate: TimeInterval, late: Bool) {
        let end = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let result = KeepAwakePolicy.isLateExpiry(
            sessionEnd: end, now: end.addingTimeInterval(secondsLate))

        #expect(result == late)
    }
}

@Suite("Focus widget")
struct FocusWidgetTests {
    @Test("Focus switches with Chap on and Chap off")
    func chapWording() {
        #expect(KeepAwakePolicy.focusIdleLine == "Chap on")
        #expect(KeepAwakePolicy.focusOffTitle == "Chap off")
    }

    @Test("the notch offers 1h, 4h, and 8h")
    func quickPresets() {
        #expect(
            KeepAwakePolicy.focusPresets.map(KeepAwakePolicy.shortTitle(of:)) == ["1h", "4h", "8h"])
        #expect(KeepAwakePolicy.shortTitle(of: KeepAwakePolicy.presets[0]) == "30m")
    }

    @Test(
        "the active line lightens as the session winds down",
        arguments: [
            (TimeInterval(3 * 3600), "Fully charged"), (3600, "In the zone"),
            (20 * 60, "Final stretch"), (2 * 60, "Landing soon"),
        ])
    func activeLine(remaining: TimeInterval, expected: String) {
        #expect(KeepAwakePolicy.focusActiveLine(remaining: remaining) == expected)
    }

    @Test("Focus is a placeable widget that round-trips")
    func widgetRoundTrips() throws {
        let config = try JSONDecoder().decode(
            Config.self, from: Data(#"{"notchWidgets": ["awake"], "sites": []}"#.utf8))
        #expect(config.notchWidgets == [.none, .none, .awake, .none, .none, .none])
        #expect(NotchWidget.awake.launchType == nil)
    }

    @Test("the Focus slot remembers a known duration and falls back to 1 hour")
    func focusPresetMemory() {
        #expect(KeepAwakePolicy.defaultFocusPreset.duration == 3600)
        #expect(KeepAwakePolicy.focusPreset(forStoredDuration: 4 * 3600).title == "4 Hours")
        #expect(KeepAwakePolicy.focusPreset(forStoredDuration: 1234).title == "1 Hour")
    }

    @Test("the progress bar shows the share of time left, or nothing without a length")
    func focusProgress() {
        #expect(KeepAwakePolicy.focusProgress(remaining: 1800, duration: 3600) == 0.5)
        #expect(KeepAwakePolicy.focusProgress(remaining: 5000, duration: 3600) == 1)
        #expect(KeepAwakePolicy.focusProgress(remaining: -5, duration: 3600) == 0)
        #expect(KeepAwakePolicy.focusProgress(remaining: 100, duration: nil) == nil)
    }
}
