import CoreGraphics
import Foundation
import Testing

@testable import Chap

@Suite("NotchShoulderPolicy – collapsed slots on the dock shoulders")
struct NotchShoulderPolicyTests {
    @Test("only Screenshots and Downloads collapse, once each, in order")
    func normalized() {
        #expect(
            NotchShoulderPolicy.normalized([.downloads, .sites, .screenshots, .downloads, .none])
                == [.downloads, .screenshots])
        #expect(NotchShoulderPolicy.normalized([.awake, .apps]) == [])
    }

    @Test("the window grows at once and shrinks after the content animation")
    func resizeSteps() {
        let wide = CGSize(width: 1400, height: 300)
        let narrow = CGSize(width: 1000, height: 300)
        // 접기: 지금은 그대로, 애니메이션 뒤 줄인다.
        let collapse = NotchLauncherPolicy.resizeSteps(current: wide, target: narrow)
        #expect(collapse.immediate == nil)
        #expect(collapse.deferred == narrow)
        // 펼치기: 바로 넓힌다.
        let expand = NotchLauncherPolicy.resizeSteps(current: narrow, target: wide)
        #expect(expand.immediate == wide)
        #expect(expand.deferred == nil)
        // 폭은 줄고 높이는 늘면: 높이만 먼저 키우고, 폭은 나중에 줄인다.
        let mixed = NotchLauncherPolicy.resizeSteps(
            current: wide, target: CGSize(width: 1000, height: 420))
        #expect(mixed.immediate == CGSize(width: 1400, height: 420))
        #expect(mixed.deferred == CGSize(width: 1000, height: 420))
        // 같으면 아무것도 안 한다.
        let same = NotchLauncherPolicy.resizeSteps(current: wide, target: wide)
        #expect(same.immediate == nil && same.deferred == nil)
        #expect(NotchLauncherPolicy.shrinkDelay > 0.22)
    }

    @Test("collapsed icons mirror the right-side strip tools across the notch")
    func leftStripIcons() {
        #expect(NotchLauncherPolicy.leftStripIconCenterOffsets(count: 2) == [13, 41])
        #expect(
            NotchLauncherPolicy.leftStripIconCenterOffsets(count: 2)
                == NotchLauncherPolicy.stripToolCenterOffsets(besideDropBadge: false, count: 2))
        #expect(NotchLauncherPolicy.leftStripIconCenterOffsets(count: 0) == [])
    }

    @Test("the strip seal steps outward when collapsed icons sit beside the notch")
    func mascotMakesRoom() {
        #expect(NotchLauncherPolicy.stripMascotCenterOffset(collapsedIconCount: 0) == 55)
        // 110 - 18 - 6 = 86: 물범(36pt)이 68…104, 아이콘 두 개는 노치에서 55pt까지.
        #expect(NotchLauncherPolicy.stripMascotCenterOffset(collapsedIconCount: 2) == 86)
    }

    @Test("collapsed widgets round-trip through the config and drop bad values")
    func configRoundTrip() throws {
        var config = Config(sites: [])
        config.notchCollapsedWidgets = [.downloads]
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded.notchCollapsedWidgets == [.downloads])

        let raw =
            #"{"sites":[],"notchCollapsedWidgets":["screenshots","sites","bogus","screenshots"]}"#
        let tolerant = try JSONDecoder().decode(Config.self, from: Data(raw.utf8))
        #expect(tolerant.notchCollapsedWidgets == [.screenshots])

        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites":[]}"#.utf8))
        #expect(missing.notchCollapsedWidgets == [])
    }
}
