import Foundation
import Testing

@testable import Chap

@Suite("Status Icon Animation Policy")
struct StatusIconAnimationPolicyTests {
    @Test(
        "CPU percent maps to clamped frames per second",
        arguments: [
            (0.0, 1.0),
            (5.0, 1.0),
            (50.0, 10.0),
            (100.0, 20.0),
            (250.0, 20.0),
        ])
    func mapsCPUToFramesPerSecond(cpuPercent: Double, expectedFPS: Double) {
        #expect(StatusIconAnimationPolicy.framesPerSecond(cpuPercent: cpuPercent) == expectedFPS)
    }

    @Test("frame interval is the reciprocal of fps")
    func frameIntervalIsReciprocal() {
        #expect(StatusIconAnimationPolicy.frameInterval(cpuPercent: 100) == 0.05)
        #expect(StatusIconAnimationPolicy.frameInterval(cpuPercent: 0) == 1.0)
    }

    @Test("frame index wraps around the frame count")
    func frameIndexWraps() {
        #expect(StatusIconAnimationPolicy.nextFrameIndex(after: 0, frameCount: 4) == 1)
        #expect(StatusIconAnimationPolicy.nextFrameIndex(after: 3, frameCount: 4) == 0)
    }

    @Test("zero frame count is safe")
    func zeroFrameCountIsSafe() {
        #expect(StatusIconAnimationPolicy.nextFrameIndex(after: 5, frameCount: 0) == 0)
    }

    @Test("both styles define four keyframes")
    func stylesDefineFourKeyframes() {
        #expect(StatusIconAnimationPolicy.pulseAlphas.count == 4)
        #expect(StatusIconAnimationPolicy.wobbleDegrees.count == 4)
    }
}

@Suite("CPU Ticks Usage")
struct CPUTicksUsageTests {
    @Test("computes busy percentage from tick deltas")
    func computesBusyPercentage() {
        let previous = CPUTicks(user: 100, system: 100, idle: 700, nice: 0)
        let current = CPUTicks(user: 150, system: 150, idle: 900, nice: 0)

        let percent = CPUTicks.usagePercent(previous: previous, current: current)

        #expect(abs(percent - 33.333) < 0.01)
    }

    @Test("zero delta yields zero usage")
    func zeroDeltaYieldsZero() {
        let ticks = CPUTicks(user: 10, system: 10, idle: 10, nice: 0)

        #expect(CPUTicks.usagePercent(previous: ticks, current: ticks) == 0)
    }

    @Test("counter wraparound is absorbed by wrapping subtraction")
    func wraparoundIsAbsorbed() {
        let previous = CPUTicks(user: UInt32.max - 10, system: 0, idle: 0, nice: 0)
        let current = CPUTicks(user: 39, system: 0, idle: 50, nice: 0)

        let percent = CPUTicks.usagePercent(previous: previous, current: current)

        #expect(abs(percent - 50.0) < 0.01)
    }
}

@Suite("StatusBarAnimationChoice")
struct StatusBarAnimationChoiceTests {
    private func decodeConfig(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    @Test("defaults to off when the key is missing")
    func defaultsToOffWhenMissing() throws {
        let config = try decodeConfig(#"{"sites": []}"#)

        #expect(config.statusBarAnimation == .off)
    }

    @Test("unknown values decode as off")
    func unknownValueDecodesAsOff() throws {
        let config = try decodeConfig(#"{"statusBarAnimation": "sparkle", "sites": []}"#)

        #expect(config.statusBarAnimation == .off)
    }

    @Test(
        "known values decode correctly",
        arguments: [("off", StatusBarAnimationChoice.off), ("pulse", .pulse), ("wobble", .wobble)])
    func knownValuesDecode(raw: String, expected: StatusBarAnimationChoice) throws {
        let config = try decodeConfig(#"{"statusBarAnimation": "\#(raw)", "sites": []}"#)

        #expect(config.statusBarAnimation == expected)
    }

    @Test("round-trips through encoding")
    func roundTripsThroughEncoding() throws {
        let original = Config(statusBarAnimation: .wobble, sites: [])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)

        #expect(decoded.statusBarAnimation == .wobble)
    }

    @Test("encodes the statusBarAnimation field")
    func encodesField() throws {
        let data = try JSONEncoder().encode(Config(statusBarAnimation: .pulse, sites: []))
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains(#""statusBarAnimation":"pulse""#))
    }
}
