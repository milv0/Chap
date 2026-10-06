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

    @Test("the row width is the expanded width that the dock keeps")
    func rowWidth() {
        #expect(NotchShoulderPolicy.rowWidth(widths: [100, 50], spacing: 20) == 170)
        #expect(NotchShoulderPolicy.rowWidth(widths: [], spacing: 20) == 0)
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
