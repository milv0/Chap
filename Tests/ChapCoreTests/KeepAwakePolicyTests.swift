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
}
