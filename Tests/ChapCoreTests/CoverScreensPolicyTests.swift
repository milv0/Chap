import AppKit
import Foundation
import SwiftUI
import Testing

@testable import Chap

@Suite("Cover Screens")
struct CoverScreensPolicyTests {
    // MARK: ⌥ 한 번으로 걷기

    @Test("tapping Option by itself lifts the cover")
    func optionTapLifts() {
        var tap = CoverScreensPolicy.OptionTap(optionHeldAtStart: false)
        let lifted1 = tap.modifiersChanged(optionDown: true, otherModifiersDown: false)
        #expect(lifted1 == false)
        let lifted2 = tap.modifiersChanged(optionDown: false, otherModifiersDown: false)
        #expect(lifted2)
    }

    @Test("letting go of ⌥ from ⌥L, which turned the cover on, does not lift it")
    func releaseFromTurnOnIsIgnored() {
        var tap = CoverScreensPolicy.OptionTap(optionHeldAtStart: true)
        let lifted3 = tap.modifiersChanged(optionDown: false, otherModifiersDown: false)
        #expect(lifted3 == false)
        // 그다음 탭은 걷는다.
        _ = tap.modifiersChanged(optionDown: true, otherModifiersDown: false)
        let lifted4 = tap.modifiersChanged(optionDown: false, otherModifiersDown: false)
        #expect(lifted4)
    }

    @Test("holding ⌥ while pressing another key is not a tap")
    func optionWithAnotherKeyDoesNotLift() {
        var tap = CoverScreensPolicy.OptionTap(optionHeldAtStart: false)
        _ = tap.modifiersChanged(optionDown: true, otherModifiersDown: false)
        tap.otherKeyPressed()  // 예: ⌥L
        let lifted5 = tap.modifiersChanged(optionDown: false, otherModifiersDown: false)
        #expect(lifted5 == false)
    }

    @Test("⌥ together with ⌘, ⌃, or ⇧ is not a tap")
    func optionWithOtherModifiersDoesNotLift() {
        var tap = CoverScreensPolicy.OptionTap(optionHeldAtStart: false)
        _ = tap.modifiersChanged(optionDown: true, otherModifiersDown: false)
        _ = tap.modifiersChanged(optionDown: true, otherModifiersDown: true)
        _ = tap.modifiersChanged(optionDown: true, otherModifiersDown: false)
        let lifted6 = tap.modifiersChanged(optionDown: false, otherModifiersDown: false)
        #expect(lifted6 == false)

        // ⌘를 먼저 누른 채 ⌥를 눌러도 아니다.
        var started = CoverScreensPolicy.OptionTap(optionHeldAtStart: false)
        _ = started.modifiersChanged(optionDown: true, otherModifiersDown: true)
        let lifted7 = started.modifiersChanged(optionDown: false, otherModifiersDown: true)
        #expect(lifted7 == false)
    }

    // MARK: 잊었을 때: 아무 키나 10번

    @Test("ten quick presses lift the cover; nine or slow ones do not")
    func rapidEscape() {
        #expect(CoverScreensPolicy.rapidPressCount == 10)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func presses(count: Int, spacing: Double) -> [Date] {
            (0..<count).map { now.addingTimeInterval(-Double(count - 1 - $0) * spacing) }
        }
        #expect(
            CoverScreensPolicy.isRapidEscape(presses: presses(count: 10, spacing: 0.25), now: now))
        #expect(
            CoverScreensPolicy.isRapidEscape(presses: presses(count: 9, spacing: 0.25), now: now)
                == false)
        // 10번이라도 1초 간격이면 창(3초)을 벗어나 모자란다.
        #expect(
            CoverScreensPolicy.isRapidEscape(presses: presses(count: 10, spacing: 1), now: now)
                == false)
    }

    @Test("only presses inside the window are kept, newest last")
    func keepsRecentPresses() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let kept = CoverScreensPolicy.recentPresses(
            [-9, -2.5, -2, -1, 0].map { now.addingTimeInterval($0) }, now: now)
        #expect(kept.count == 4)
        #expect(kept.first == now.addingTimeInterval(-2.5))
        #expect(kept.last == now)
    }

    @Test("held-down key repeats do not count toward the ten presses")
    func repeatsDoNotCount() {
        #expect(CoverScreensPolicy.countsAsPress(isRepeat: false))
        #expect(CoverScreensPolicy.countsAsPress(isRepeat: true) == false)
    }

    @Test("the clock goes on the built-in screen; the others get the resting seal")
    func clockScreenChoice() {
        // 외장 모니터가 첫 화면(메뉴 막대)이어도 내장 화면이 시계를 맡는다.
        #expect(CoverScreensPolicy.clockScreenIndex(builtIn: [false, true]) == 1)
        #expect(CoverScreensPolicy.clockScreenIndex(builtIn: [true, false, false]) == 0)
        // 내장 화면이 없으면(덮개를 닫음 등) 첫 화면.
        #expect(CoverScreensPolicy.clockScreenIndex(builtIn: [false, false]) == 0)
        #expect(CoverScreensPolicy.clockScreenIndex(builtIn: []) == 0)
    }

    @Test("the hint says to tap Option")
    func hintNamesOption() {
        #expect(CoverScreensPolicy.hint == "Tap ⌥ Option to come back")
    }

    // MARK: 사용자 문구

    @Test("the message becomes one tidy line, or nothing when empty")
    func cleansMessage() {
        #expect(CoverScreensPolicy.cleanedMessage(nil) == nil)
        #expect(CoverScreensPolicy.cleanedMessage("") == nil)
        #expect(CoverScreensPolicy.cleanedMessage("   ") == nil)
        #expect(CoverScreensPolicy.cleanedMessage("  Back in 10  ") == "Back in 10")
        #expect(CoverScreensPolicy.cleanedMessage("At lunch\nback at 1") == "At lunch back at 1")
        #expect(CoverScreensPolicy.cleanedMessage("회의 중입니다 ☕️") == "회의 중입니다 ☕️")
        let long = String(repeating: "a", count: CoverScreensPolicy.messageMaxLength + 20)
        #expect(
            CoverScreensPolicy.cleanedMessage(long)?.count == CoverScreensPolicy.messageMaxLength)
    }

    @Test("the message is optional in config and round-trips")
    func messageConfig() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.coverScreensMessage == nil)

        let config = Config(coverScreensMessage: " Back soon ", sites: [])
        #expect(config.coverScreensMessage == "Back soon")
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        #expect(decoded.coverScreensMessage == "Back soon")

        // 없으면 파일에 키를 쓰지 않는다.
        let json = try #require(
            String(data: try JSONEncoder().encode(missing), encoding: .utf8))
        #expect(json.contains("coverScreensMessage") == false)
    }

    @Test("the seal breathes around its resting brightness, never fading out")
    func breathRange() {
        let range = CoverScreensPolicy.sealBreathOpacity
        #expect(range.contains(CoverScreensPolicy.sealOpacity))
        #expect(range.lowerBound >= 0.4)
        #expect(range.upperBound <= 0.8)
        #expect(CoverScreensPolicy.sealBreathDuration >= 1.5)
    }

    @Test("⌥L is the default shortcut; older configs get it, and clearing it turns it off")
    func shortcutConfig() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.coverScreensShortcut == "L")

        let off = try JSONDecoder().decode(
            Config.self, from: Data(#"{"coverScreensShortcut": "", "sites": []}"#.utf8))
        #expect(off.coverScreensShortcut == nil)

        for value in ["K", nil] as [String?] {
            let config = Config(coverScreensShortcut: value, sites: [])
            let decoded = try JSONDecoder().decode(
                Config.self, from: JSONEncoder().encode(config))
            #expect(decoded.coverScreensShortcut == value)
        }
    }

    @Test("sites and Quick Note keep their keys; Cover Screens steps aside")
    func shortcutConflicts() {
        let site = Site(
            name: "Linear", url: "https://linear.app", width: 800, height: 600, shortcut: "L")
        #expect(
            CoverScreensPolicy.registeredShortcut("L", sites: [], quickNoteKey: "N") == "L")
        #expect(
            CoverScreensPolicy.registeredShortcut("L", sites: [site], quickNoteKey: "N") == nil)
        #expect(
            CoverScreensPolicy.conflict(for: "L", sites: [site], quickNoteKey: nil)
                == .site(name: "Linear"))
        #expect(
            CoverScreensPolicy.registeredShortcut("N", sites: [], quickNoteKey: "N") == nil)
        #expect(
            CoverScreensPolicy.conflict(for: "N", sites: [], quickNoteKey: "N")
                == .feature(name: "Quick Note"))
        #expect(CoverScreensPolicy.registeredShortcut(nil, sites: [], quickNoteKey: nil) == nil)
        #expect(CoverScreensPolicy.registeredShortcut(".", sites: [], quickNoteKey: nil) == nil)
    }

    @Test("⌥L registers after Quick Note")
    func hotKeyOrder() {
        let registrations = globalHotKeyRegistrations(
            for: [], optionShortcutsEnabled: true, quickNoteKey: "N", coverScreensKey: "L")
        #expect(
            registrations.suffix(2) == [
                GlobalHotKeyRegistration(character: "N", action: .openQuickNote),
                GlobalHotKeyRegistration(character: "L", action: .coverScreens),
            ])
    }

    @Test("the menu reads Cover Screens and Uncover Screens, like Focus on and off")
    func menuWording() {
        #expect(CoverScreensPolicy.menuTitleOff == "Cover Screens")
        #expect(CoverScreensPolicy.menuTitleOn == "Uncover Screens")
    }

    @Test("the notch strip icon is on by default and its setting round-trips")
    func stripIconSetting() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.notchCoverScreensEnabled)

        let off = Config(notchCoverScreensEnabled: false, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(off))
        #expect(decoded.notchCoverScreensEnabled == false)
    }

    @Test("with Mirror, Quick Note, and Cover Screens, the last icon stays on the flat strip")
    func threeStripToolsFit() {
        let offsets = NotchLauncherPolicy.stripToolCenterOffsets(besideDropBadge: true, count: 3)
        #expect(offsets.count == 3)
        // 아이콘 글자(14pt)의 절반 이상 여유를 두고 평평한 띠(110pt) 안에 들어온다.
        let last = offsets.last ?? .infinity
        #expect(last + 12 <= NotchGeometry.stripPlateauSideWidth)
    }

    @Test("settings saved as Lights Out (2.10.1 and earlier) carry over to Cover Screens")
    func migratesLightsOutKeys() throws {
        let old = try JSONDecoder().decode(
            Config.self,
            from: Data(
                #"{"lightsOutShortcut": "K", "notchLightsOutEnabled": false, "lightsOutUnlockKey": "esc", "sites": []}"#
                    .utf8))
        #expect(old.coverScreensShortcut == "K")
        #expect(old.notchCoverScreensEnabled == false)

        // 끈 단축키("")도 그대로 옮긴다.
        let off = try JSONDecoder().decode(
            Config.self, from: Data(#"{"lightsOutShortcut": "", "sites": []}"#.utf8))
        #expect(off.coverScreensShortcut == nil)

        // 새 이름이 있으면 새 이름이 이긴다.
        let both = try JSONDecoder().decode(
            Config.self,
            from: Data(
                #"{"coverScreensShortcut": "J", "lightsOutShortcut": "K", "sites": []}"#.utf8))
        #expect(both.coverScreensShortcut == "J")

        // 다시 저장하면 새 이름만 남는다.
        let json = try #require(
            String(data: try JSONEncoder().encode(old), encoding: .utf8))
        #expect(json.contains("coverScreensShortcut"))
        #expect(json.contains("lightsOut") == false)
    }
    @Test("the companion seal drifts and bounces back from the edges like a screensaver")
    func companionDriftBounces() {
        let container = CGSize(width: 1000, height: 600)
        let item = CGSize(width: 200, height: 100)
        // CGPoint 좌표와 같은 타입으로 비교한다.
        let margin = CGFloat(CoverScreensPolicy.companionDriftMargin)
        func origin(_ t: Double, start: CGPoint = .zero) -> CGPoint {
            CoverScreensPolicy.companionDriftOrigin(
                elapsed: t, container: container, item: item, start: start, speed: 100)
        }
        // 가로 범위 1000-200-80 = 720, 세로 600-100-80 = 420.
        #expect(origin(0) == CGPoint(x: margin, y: margin))
        #expect(origin(1) == CGPoint(x: margin + 80, y: margin + 60))
        // 오른쪽 끝(720)에 닿은 뒤(9초) 되돌아온다.
        #expect(origin(10).x == margin + 720 - 80)
        // 한 바퀴(가로 2×720 ÷ 80 = 18초)면 제자리.
        #expect(origin(18).x == margin)
        for t in stride(from: 0.0, through: 120, by: 0.7) {
            let point = origin(t, start: CGPoint(x: 0.3, y: 0.9))
            #expect(point.x >= margin && point.x <= container.width - item.width - margin)
            #expect(point.y >= margin && point.y <= container.height - item.height - margin)
            #expect(point.x == point.x.rounded() && point.y == point.y.rounded())
        }
    }

    @Test("a screen too small to drift keeps the seal centered on that axis")
    func companionDriftSmallScreen() {
        let point = CoverScreensPolicy.companionDriftOrigin(
            elapsed: 50, container: CGSize(width: 250, height: 600),
            item: CGSize(width: 200, height: 100), start: CGPoint(x: 1, y: 0))
        #expect(point.x == 25)
        #expect(point.y > CGFloat(CoverScreensPolicy.companionDriftMargin))
    }
}

/// 실제 가림막 창을 띄워 걷는 길을 확인한다. 화면이 잠깐 검게 덮이므로 렌더 도구와 같은
/// 환경 변수를 줬을 때만 돈다: TEST_RUNNER_CHAP_NOTCH_RENDER_DIR=/tmp/x xcodebuild ... test
@Suite(
    "Cover Screens controller", .serialized, .enabled(if: NotchRenderTool.outputDirectory != nil))
@MainActor
struct CoverScreensControllerTests {
    private func key(_ code: UInt16, _ chars: String, isRepeat: Bool = false) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: chars, charactersIgnoringModifiers: chars,
                isARepeat: isRepeat, keyCode: code))
    }

    /// 수식키 변화 이벤트. ⌥만 누르고 떼는 것은 일반 키가 아니라 이것으로 온다.
    private func flags(_ modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        let cg = try #require(CGEvent(source: nil))
        cg.type = .flagsChanged
        cg.flags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))
        return try #require(NSEvent(cgEvent: cg))
    }

    @Test("it covers every screen and a tap of ⌥ lifts it")
    func optionTapLifts() throws {
        let controller = CoverScreensController()
        controller.turnOn()
        defer { controller.turnOff() }
        #expect(controller.isOn)
        #expect(controller.coveredScreenCount == NSScreen.screens.count)

        // Esc는 더 이상 걷지 않는다 (삼킨다).
        #expect(try controller.handle(key(53, "\u{1B}")) == false)
        #expect(controller.isOn)

        #expect(try controller.handle(flags(.option)) == false)
        #expect(try controller.handle(flags([])))
        #expect(controller.isOn == false)
        #expect(controller.coveredScreenCount == 0)
    }

    @Test("⌥ held with another key does not lift it")
    func optionChordDoesNotLift() throws {
        let controller = CoverScreensController()
        controller.turnOn()
        defer { controller.turnOff() }
        _ = try controller.handle(flags(.option))
        _ = try controller.handle(key(37, "l"))
        #expect(try controller.handle(flags([])) == false)
        #expect(controller.isOn)
    }

    @Test("ten quick presses lift it; held-down repeats do not")
    func rapidPressesLift() throws {
        let controller = CoverScreensController()
        controller.turnOn()
        defer { controller.turnOff() }
        let start = Date()

        for index in 0..<30 {
            _ = try controller.handle(
                key(0, "a", isRepeat: true), now: start.addingTimeInterval(Double(index) * 0.05))
        }
        #expect(controller.isOn)

        for index in 0..<9 {
            _ = try controller.handle(
                key(0, "a"), now: start.addingTimeInterval(2 + Double(index) * 0.2))
        }
        #expect(controller.isOn)
        #expect(try controller.handle(key(0, "a"), now: start.addingTimeInterval(3.9)))
        #expect(controller.isOn == false)
    }

    /// 물범이 정말 움직이는지: 같은 화면을 시간차로 두 번 찍어 픽셀이 바뀌었는지 본다(숨·z).
    @Test("the napping seal is animated, not a still image")
    func sealMoves() throws {
        let hosting = NSHostingView(
            rootView: CoverScreensView(showsClock: true, hint: "Press Esc to come back")
                .frame(width: 600, height: 420))
        let window = NSWindow(
            contentRect: CGRect(x: -10_000, y: -10_000, width: 600, height: 420),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        func snapshot() throws -> Data {
            let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            // 시계 줄(아래쪽)은 분이 바뀌면 달라질 수 있으니 물범이 있는 위쪽 절반만 비교한다.
            let data = try #require(rep.bitmapData)
            return Data(bytes: data, count: rep.bytesPerRow * rep.pixelsHigh / 2)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let first = try snapshot()
        RunLoop.main.run(until: Date().addingTimeInterval(1.6))
        let second = try snapshot()
        #expect(first != second)
    }

}
