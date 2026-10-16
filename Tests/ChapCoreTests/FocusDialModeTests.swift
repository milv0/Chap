import Foundation
import Testing

@testable import Chap

@Suite("Focus dial mode")
struct FocusDialModeTests {
    @Test("the slot opens on whichever one is running")
    func runningWins() {
        #expect(
            FocusDialMode.initial(stored: "focus", isFocusRunning: false, isTimerRunning: true)
                == .timer)
        #expect(
            FocusDialMode.initial(stored: "timer", isFocusRunning: true, isTimerRunning: false)
                == .focus)
    }

    @Test("otherwise it opens on the last mode picked")
    func storedMode() {
        #expect(
            FocusDialMode.initial(stored: "timer", isFocusRunning: false, isTimerRunning: false)
                == .timer)
        #expect(
            FocusDialMode.initial(stored: "timer", isFocusRunning: true, isTimerRunning: true)
                == .timer)
        #expect(
            FocusDialMode.initial(stored: "focus", isFocusRunning: false, isTimerRunning: false)
                == .focus)
    }

    @Test("with nothing stored, or something unknown, it opens on Focus")
    func defaultMode() {
        #expect(
            FocusDialMode.initial(stored: nil, isFocusRunning: false, isTimerRunning: false)
                == .focus)
        #expect(
            FocusDialMode.initial(stored: "stopwatch", isFocusRunning: false, isTimerRunning: false)
                == .focus)
    }

    @Test("the tabs read Focus and Timer, in that order")
    func tabs() {
        #expect(FocusDialMode.allCases.map(\.title) == ["Focus", "Timer"])
        #expect(FocusDialMode.allCases.map(\.symbol) == ["bolt.fill", "timer"])
    }
}

@Suite("Timer slot migration")
struct TimerSlotMigrationTests {
    private func widgets(_ raw: String) throws -> [NotchWidget] {
        let json = #"{"notchWidgets": \#(raw), "sites": []}"#
        return try JSONDecoder().decode(Config.self, from: Data(json.utf8)).notchWidgets
    }

    @Test("a 2.14 Timer slot becomes the Focus slot in the same place")
    func timerBecomesFocus() throws {
        #expect(
            try widgets(#"["screenshots", "none", "sites", "timer", "apps"]"#)
                == [.screenshots, .none, .launchers, .awake, .apps, .none])
    }

    @Test("with Focus already placed, the Timer slot is left empty so nothing shifts")
    func timerBesideFocusEmpties() throws {
        #expect(
            try widgets(#"["screenshots", "none", "awake", "sites", "timer", "apps"]"#)
                == [.screenshots, .none, .awake, .launchers, .none, .apps])
        #expect(
            try widgets(#"["screenshots", "none", "timer", "sites", "awake", "apps"]"#)
                == [.screenshots, .none, .none, .launchers, .awake, .apps])
    }

    @Test("Timer is no longer a slot of its own")
    func timerIsNotASlot() {
        #expect(NotchWidget(rawValue: NotchWidget.formerTimerRawValue) == nil)
    }
}
