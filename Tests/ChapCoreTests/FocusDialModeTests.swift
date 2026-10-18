import Foundation
import Testing

@testable import Chap

@Suite("Focus dial mode")
struct FocusDialModeTests {
    @Test("the slot opens on whichever one is running")
    func runningWins() {
        #expect(
            FocusDialMode.initial(stored: "focus", isAwakeRunning: false, isTimerRunning: true)
                == .timer)
        #expect(
            FocusDialMode.initial(stored: "timer", isAwakeRunning: true, isTimerRunning: false)
                == .keepAwake)
    }

    @Test("otherwise it opens on the last mode picked")
    func storedMode() {
        #expect(
            FocusDialMode.initial(stored: "timer", isAwakeRunning: false, isTimerRunning: false)
                == .timer)
        #expect(
            FocusDialMode.initial(stored: "timer", isAwakeRunning: true, isTimerRunning: true)
                == .timer)
        #expect(
            FocusDialMode.initial(stored: "focus", isAwakeRunning: false, isTimerRunning: false)
                == .keepAwake)
    }

    @Test("with nothing stored, or something unknown, it opens on Keep Awake")
    func defaultMode() {
        #expect(
            FocusDialMode.initial(stored: nil, isAwakeRunning: false, isTimerRunning: false)
                == .keepAwake)
        #expect(
            FocusDialMode.initial(stored: "stopwatch", isAwakeRunning: false, isTimerRunning: false)
                == .keepAwake)
    }

    @Test("the tabs read Keep Awake and Timer, in that order")
    func tabs() {
        #expect(FocusDialMode.allCases.map(\.title) == ["Keep Awake", "Timer"])
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

@Suite("Keep Awake dial mode – stored value")
struct KeepAwakeDialStoredValueTests {
    @Test("a mode saved as \"focus\" before the rename still opens on Keep Awake")
    func legacyValue() {
        #expect(FocusDialMode.keepAwake.rawValue == "focus")
        #expect(
            FocusDialMode.initial(stored: "focus", isAwakeRunning: false, isTimerRunning: false)
                == .keepAwake)
    }
}
