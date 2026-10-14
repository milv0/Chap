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

    @Test("the length steps by 5 minutes and stays between 5 minutes and 1 hour")
    func stepping() {
        #expect(TimerPolicy.stepped(25 * 60, by: 1) == 30 * 60)
        #expect(TimerPolicy.stepped(25 * 60, by: -1) == 20 * 60)
        #expect(TimerPolicy.stepped(5 * 60, by: -1) == 5 * 60)
        #expect(TimerPolicy.stepped(60 * 60, by: 1) == 60 * 60)
        // 손으로 고친 값도 5분 눈금에 맞춘다.
        #expect(TimerPolicy.stepped(23 * 60, by: 1) == 25 * 60)
    }

    @Test("a stored length outside the range falls back to the default")
    func storedLength() {
        #expect(TimerPolicy.length(forStored: 0) == TimerPolicy.defaultLength)
        // 2.14의 노치 칸은 3시간까지 골랐다. 1시간을 넘는 저장값은 기본 길이로 돌아간다.
        #expect(TimerPolicy.length(forStored: 90 * 60) == TimerPolicy.defaultLength)
        #expect(TimerPolicy.length(forStored: 45 * 60) == 45 * 60)
        #expect(TimerPolicy.length(forStored: 60 * 60) == 60 * 60)
    }

    @Test("every menu preset fits on the dial")
    func presetsFitTheDial() {
        #expect(TimerPolicy.presets.allSatisfy(TimerPolicy.lengthRange.contains))
        #expect(TimerPolicy.presets.last == TimerPolicy.lengthRange.upperBound)
    }

    @Test(
        "the dial maps 0 to 60 minutes across the arc in 5-minute notches",
        arguments: [
            (0.0, 5.0),
            (0.03, 5.0),
            (5.0 / 12, 25.0),
            (0.5, 30.0),
            (0.46, 30.0),
            (1.0, 60.0),
        ] as [(Double, Double)])
    func dialLength(fraction: Double, expectedMinutes: Double) {
        #expect(TimerPolicy.dialLength(fraction: fraction) == expectedMinutes * 60)
    }

    @Test("the dial fraction follows the time on the same 60-minute scale")
    func dialFraction() {
        #expect(TimerPolicy.dialFraction(length: 30 * 60) == 0.5)
        #expect(TimerPolicy.dialFraction(length: 60 * 60) == 1)
        #expect(TimerPolicy.dialFraction(length: 0) == 0)
        #expect(TimerPolicy.dialFraction(length: 90 * 60) == 1)
        // 고른 길이는 다이얼에서 같은 자리로 돌아온다.
        for length in stride(from: 5 * 60.0, through: 60 * 60, by: 5 * 60) {
            #expect(
                TimerPolicy.dialLength(fraction: TimerPolicy.dialFraction(length: length)) == length
            )
        }
    }

    @Test("the dial center reads minutes, with Start or Stop under it")
    func dialWording() {
        #expect(TimerPolicy.dialLabel(length: 25 * 60) == "25m")
        #expect(TimerPolicy.dialLabel(length: 60 * 60) == "60m")
        #expect(TimerPolicy.dialStartLabel == "Start")
        #expect(TimerPolicy.dialStopLabel == "Stop")
        #expect(TimerPolicy.dialMaxLabel == "60m")
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
