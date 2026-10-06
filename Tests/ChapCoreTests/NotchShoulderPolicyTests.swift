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

    @Test("slots left of the row center go to the left shoulder, the rest to the right")
    func sides() {
        // 6칸: 앞 셋은 왼쪽, 뒤 셋은 오른쪽.
        let widths: [CGFloat] = [130, 160, 150, 84, 130, 112]
        #expect(
            NotchShoulderPolicy.sides(widths: widths, spacing: 20)
                == [.left, .left, .left, .right, .right, .right])
        // 한 칸뿐이면 가운데 → 왼쪽.
        #expect(NotchShoulderPolicy.sides(widths: [160], spacing: 20) == [.left])
        #expect(NotchShoulderPolicy.sides(widths: [], spacing: 20) == [])
    }

    @Test("the row width is the expanded width that the dock keeps")
    func rowWidth() {
        #expect(NotchShoulderPolicy.rowWidth(widths: [100, 50], spacing: 20) == 170)
        #expect(NotchShoulderPolicy.rowWidth(widths: [], spacing: 20) == 0)
    }

    @Test("icons start at the outer edge and step inward by the pitch")
    func iconCenters() {
        // 플레어 10 + 여백 8 + 반 피치 14 = 32.
        #expect(NotchShoulderPolicy.iconCenterX(side: .left, index: 0, dockWidth: 800) == 32)
        #expect(NotchShoulderPolicy.iconCenterX(side: .left, index: 1, dockWidth: 800) == 60)
        #expect(NotchShoulderPolicy.iconCenterX(side: .right, index: 0, dockWidth: 800) == 768)
        #expect(NotchShoulderPolicy.iconCenterX(side: .right, index: 1, dockWidth: 800) == 740)
        #expect(NotchShoulderPolicy.iconCenterY(topInset: 32, edgeDepth: 6) == 22)
        #expect(NotchShoulderPolicy.iconCenterY(topInset: 32, edgeDepth: 0) == 19)
        #expect(NotchShoulderPolicy.iconSize == 16)
    }

    @Test("the dock is wide enough to keep shoulder icons clear of the black curve")
    func minimumDockWidth() {
        // 반폭 = plateau 202.5 + 감쇠 90 + 플레어 10 + 여백 8 + 28 × 2 = 366.5.
        #expect(
            NotchShoulderPolicy.minimumDockWidth(iconsPerSide: 2, plateauHalfWidth: 202.5) == 733)
        #expect(
            NotchShoulderPolicy.minimumDockWidth(iconsPerSide: 0, plateauHalfWidth: 202.5) == 0)
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
