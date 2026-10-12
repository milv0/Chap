import AppKit
import Foundation
import Testing

@testable import Chap

@Suite("Lights Out")
struct LightsOutPolicyTests {
    @Test("the unlock key falls back to Esc, and a letter is stored uppercase")
    func normalizesKey() {
        #expect(LightsOutPolicy.normalized(nil) == "esc")
        #expect(LightsOutPolicy.normalized("") == "esc")
        #expect(LightsOutPolicy.normalized("   ") == "esc")
        #expect(LightsOutPolicy.normalized("ESC") == "esc")
        #expect(LightsOutPolicy.normalized("k") == "K")
        #expect(LightsOutPolicy.normalized("  back ") == "B")
        #expect(LightsOutPolicy.label(for: "esc") == "Esc")
        #expect(LightsOutPolicy.label(for: "k") == "K")
    }

    @Test("Esc unlocks when it is the key; a letter key needs that letter")
    func unlockMatching() {
        #expect(LightsOutPolicy.unlocks(isEscape: true, characters: nil, unlockKey: "esc"))
        #expect(
            LightsOutPolicy.unlocks(isEscape: false, characters: "a", unlockKey: "esc") == false)

        #expect(LightsOutPolicy.unlocks(isEscape: false, characters: "k", unlockKey: "K"))
        #expect(LightsOutPolicy.unlocks(isEscape: false, characters: "K", unlockKey: "K"))
        // 글자 키를 골랐으면 Esc로는 걷히지 않는다 (대신 연타로 빠져나온다).
        #expect(LightsOutPolicy.unlocks(isEscape: true, characters: nil, unlockKey: "K") == false)
        #expect(
            LightsOutPolicy.unlocks(isEscape: false, characters: "j", unlockKey: "K") == false)
    }

    @Test("five quick presses lift the cover; slow presses do not")
    func rapidEscape() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func presses(_ offsets: [Double]) -> [Date] {
            offsets.map { now.addingTimeInterval($0) }
        }
        // 1.6초 안에 다섯 번.
        #expect(
            LightsOutPolicy.isRapidEscape(presses: presses([-1.6, -1.2, -0.8, -0.4, 0]), now: now))
        // 네 번은 아직 아니다.
        #expect(
            LightsOutPolicy.isRapidEscape(presses: presses([-1.2, -0.8, -0.4, 0]), now: now)
                == false)
        // 느리게 다섯 번은 창을 벗어나 세지 않는다.
        #expect(
            LightsOutPolicy.isRapidEscape(presses: presses([-9, -7, -5, -3, 0]), now: now) == false)
    }

    @Test("only presses inside the window are kept, newest last")
    func keepsRecentPresses() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let kept = LightsOutPolicy.recentPresses(
            [-5, -1.5, -1, -0.5, -0.2, 0].map { now.addingTimeInterval($0) }, now: now)
        #expect(kept.count == 5)
        #expect(kept.first == now.addingTimeInterval(-1.5))
        #expect(kept.last == now)
    }

    @Test("editing the key field: deleting goes back to Esc, typing takes the last letter")
    func keyFieldEditing() {
        // 칸에 "Esc"가 보일 때 한 글자를 지우면 "S"가 아니라 Esc로 돌아간다.
        #expect(LightsOutPolicy.keyAfterEditing(currentKey: "esc", newText: "Es") == "esc")
        #expect(LightsOutPolicy.keyAfterEditing(currentKey: "esc", newText: "") == "esc")
        #expect(LightsOutPolicy.keyAfterEditing(currentKey: "esc", newText: "Esck") == "K")
        #expect(LightsOutPolicy.keyAfterEditing(currentKey: "K", newText: "Kj") == "J")
        #expect(LightsOutPolicy.keyAfterEditing(currentKey: "K", newText: "") == "esc")
    }

    @Test("held-down key repeats do not count toward the five quick presses")
    func repeatsDoNotCount() {
        #expect(LightsOutPolicy.countsAsPress(isRepeat: false))
        #expect(LightsOutPolicy.countsAsPress(isRepeat: true) == false)
    }

    @Test("the hint names the key the user actually set")
    func hintNamesKey() {
        #expect(LightsOutPolicy.hint(unlockKey: "esc") == "Press Esc to come back")
        #expect(LightsOutPolicy.hint(unlockKey: "k") == "Press K to come back")
    }

    @Test("the menu reads Lights Out and Lights On, like Focus on and off")
    func menuWording() {
        #expect(LightsOutPolicy.menuTitleOff == "Lights Out")
        #expect(LightsOutPolicy.menuTitleOn == "Lights On")
    }

    @Test("the notch strip icon is on by default and its setting round-trips")
    func stripIconSetting() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.notchLightsOutEnabled)

        let off = Config(notchLightsOutEnabled: false, sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(off))
        #expect(decoded.notchLightsOutEnabled == false)
    }

    @Test("with Mirror, Quick Note, and Lights Out, the last icon stays on the flat strip")
    func threeStripToolsFit() {
        let offsets = NotchLauncherPolicy.stripToolCenterOffsets(besideDropBadge: true, count: 3)
        #expect(offsets.count == 3)
        // 아이콘 글자(14pt)의 절반 이상 여유를 두고 평평한 띠(110pt) 안에 들어온다.
        let last = offsets.last ?? .infinity
        #expect(last + 12 <= NotchGeometry.stripPlateauSideWidth)
    }

    @Test("an older config gets Esc, and the key round-trips")
    func configRoundTrip() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.lightsOutUnlockKey == "esc")

        let garbage = try JSONDecoder().decode(
            Config.self, from: Data(#"{"lightsOutUnlockKey": "", "sites": []}"#.utf8))
        #expect(garbage.lightsOutUnlockKey == "esc")

        let config = Config(lightsOutUnlockKey: "k", sites: [])
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        #expect(decoded.lightsOutUnlockKey == "K")
    }
}

/// 실제 가림막 창을 띄워 해제 경로를 확인한다. 화면이 잠깐 검게 덮이므로 렌더 도구와 같은
/// 환경 변수를 줬을 때만 돈다: TEST_RUNNER_CHAP_NOTCH_RENDER_DIR=/tmp/x xcodebuild ... test
@Suite("Lights Out controller", .serialized, .enabled(if: NotchRenderTool.outputDirectory != nil))
@MainActor
struct LightsOutControllerTests {
    private func key(_ code: UInt16, _ chars: String, isRepeat: Bool = false) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: chars, charactersIgnoringModifiers: chars,
                isARepeat: isRepeat, keyCode: code))
    }

    @Test("it covers every screen and Esc lifts it")
    func escapeLifts() throws {
        let controller = LightsOutController()
        controller.turnOn()
        defer { controller.turnOff() }
        #expect(controller.isOn)
        #expect(controller.coveredScreenCount == NSScreen.screens.count)

        #expect(try controller.handleKeyDown(key(0, "a")) == false)
        #expect(controller.isOn)
        #expect(try controller.handleKeyDown(key(53, "\u{1B}")))
        #expect(controller.isOn == false)
        #expect(controller.coveredScreenCount == 0)
    }

    @Test("with a letter key, five quick presses still lift it; held-down repeats do not")
    func rapidPressesLift() throws {
        let controller = LightsOutController()
        controller.unlockKeyProvider = { "K" }
        controller.turnOn()
        defer { controller.turnOff() }
        let start = Date()

        // 키를 누르고 있는 자동 반복은 아무리 많아도 걷지 않는다.
        for index in 0..<10 {
            _ = try controller.handleKeyDown(
                key(0, "a", isRepeat: true), now: start.addingTimeInterval(Double(index) * 0.05))
        }
        #expect(controller.isOn)

        // Esc는 해제 키가 아니지만 연타 한 번으로는 센다.
        for index in 0..<4 {
            _ = try controller.handleKeyDown(
                key(53, "\u{1B}"), now: start.addingTimeInterval(1 + Double(index) * 0.2))
        }
        #expect(controller.isOn)
        #expect(
            try controller.handleKeyDown(key(0, "a"), now: start.addingTimeInterval(1.8)))
        #expect(controller.isOn == false)
    }

    @Test("the chosen letter lifts it directly")
    func letterLifts() throws {
        let controller = LightsOutController()
        controller.unlockKeyProvider = { "K" }
        controller.turnOn()
        defer { controller.turnOff() }
        #expect(try controller.handleKeyDown(key(40, "k")))
        #expect(controller.isOn == false)
    }
}
