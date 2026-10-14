import Foundation
import Testing

@testable import Chap

@Suite("Timer policy")
struct TimerPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test(
        "the clock shows m:ss under an hour and h:mm:ss above, rounding seconds up",
        arguments: [
            (25 * 60.0, "25:00"),
            (59.2, "1:00"),
            (0.4, "0:01"),
            (3600.0, "1:00:00"),
            (3725.0, "1:02:05"),
            (0.0, "0:00"),
            (-5.0, "0:00"),
        ])
    func clockLabel(remaining: Double, expected: String) {
        #expect(
            TimerPolicy.clockLabel(until: now.addingTimeInterval(remaining), now: now) == expected)
    }

    @Test("the length steps by 5 minutes and stays between 5 minutes and 3 hours")
    func stepping() {
        #expect(TimerPolicy.stepped(25 * 60, by: 1) == 30 * 60)
        #expect(TimerPolicy.stepped(25 * 60, by: -1) == 20 * 60)
        #expect(TimerPolicy.stepped(5 * 60, by: -1) == 5 * 60)
        #expect(TimerPolicy.stepped(180 * 60, by: 1) == 180 * 60)
        // 손으로 고친 값도 5분 눈금에 맞춘다.
        #expect(TimerPolicy.stepped(23 * 60, by: 1) == 25 * 60)
    }

    @Test("a stored length outside the range falls back to the default")
    func storedLength() {
        #expect(TimerPolicy.length(forStored: 0) == TimerPolicy.defaultLength)
        #expect(TimerPolicy.length(forStored: 999 * 60) == TimerPolicy.defaultLength)
        #expect(TimerPolicy.length(forStored: 45 * 60) == 45 * 60)
    }

    @Test("progress runs from 0 to 1 over the timer's length")
    func progress() {
        let end = now.addingTimeInterval(600)
        #expect(TimerPolicy.progress(end: end, length: 1200, now: now) == 0.5)
        #expect(TimerPolicy.progress(end: end, length: 600, now: now) == 0)
        #expect(TimerPolicy.progress(end: end, length: 600, now: end) == 1)
        #expect(TimerPolicy.progress(end: end, length: 0, now: now) == 1)
    }

    @Test("menu titles name the minutes, and show time left while running")
    func menuTitles() {
        #expect(TimerPolicy.presetTitle(5 * 60) == "5 Minutes")
        #expect(TimerPolicy.presetTitle(60 * 60) == "1 Hour")
        #expect(TimerPolicy.menuTitle(end: nil, now: now) == "Timer")
        #expect(
            TimerPolicy.menuTitle(end: now.addingTimeInterval(90), now: now) == "Timer — 1:30 left")
    }

    @Test("the timer badge sits left of the notch, mirroring the Drop badge on the right")
    func badgeFrame() {
        let notch = CGRect(x: 600, y: 868, width: 200, height: 32)

        let timer = NotchLauncherPolicy.timerBadgeFrame(notchRect: notch)
        let drop = NotchLauncherPolicy.dropBadgeFrame(notchRect: notch)

        #expect(timer.maxX == notch.minX + NotchLauncherPolicy.dropBadgeNotchOverlap)
        #expect(drop.minX == notch.maxX - NotchLauncherPolicy.dropBadgeNotchOverlap)
        #expect(timer.minY == notch.minY && timer.height == notch.height)
        #expect(timer.width > drop.width)
    }
}
