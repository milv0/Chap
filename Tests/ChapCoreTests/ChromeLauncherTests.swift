import Foundation
import Testing

@testable import Chap

@Suite("Chrome Unresponsive Detection")
struct ChromeLauncherTests {
    @Test("running Chrome with zero AX windows and no new window looks unresponsive")
    func runningWithNoWindowsIsUnresponsive() {
        #expect(
            ChromeLauncher.chromeAppearsUnresponsive(
                chromeRunning: true, baselineWindowCount: 0, foundNewWindow: false))
    }

    @Test("a found new window is never treated as unresponsive")
    func foundWindowIsHealthy() {
        #expect(
            !ChromeLauncher.chromeAppearsUnresponsive(
                chromeRunning: true, baselineWindowCount: 0, foundNewWindow: true))
    }

    @Test("existing baseline windows mean Chrome is responding")
    func baselineWindowsAreHealthy() {
        #expect(
            !ChromeLauncher.chromeAppearsUnresponsive(
                chromeRunning: true, baselineWindowCount: 2, foundNewWindow: false))
    }

    @Test("a cold start with no prior windows is not flagged")
    func coldStartIsNotFlagged() {
        #expect(
            !ChromeLauncher.chromeAppearsUnresponsive(
                chromeRunning: false, baselineWindowCount: 0, foundNewWindow: false))
    }

    // MARK: - Version Mismatch Detection

    @Test("parses framework version from a loaded dylib path")
    func parsesFrameworkVersion() {
        let path =
            "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/150.0.7871.189/Google Chrome Framework"
        #expect(ChromeLauncher.frameworkVersion(fromLoadedPath: path) == "150.0.7871.189")
    }

    @Test("returns nil when the path has no versions segment")
    func versionParsingReturnsNilForUnrelatedPath() {
        #expect(
            ChromeLauncher.frameworkVersion(
                fromLoadedPath: "/usr/lib/libSystem.dylib") == nil)
    }

    @Test("different running and disk versions mean a relaunch is pending")
    func mismatchedVersionsArePending() {
        #expect(
            ChromeLauncher.isPendingRelaunch(
                runningVersion: "150.0.7871.189", diskVersion: "151.0.7922.76"))
    }

    @Test("matching versions are not pending")
    func matchingVersionsAreNotPending() {
        #expect(
            !ChromeLauncher.isPendingRelaunch(
                runningVersion: "151.0.7922.76", diskVersion: "151.0.7922.76"))
    }

    @Test("unknown version on either side is not treated as pending")
    func unknownVersionIsNotPending() {
        #expect(!ChromeLauncher.isPendingRelaunch(runningVersion: nil, diskVersion: "151.0"))
        #expect(!ChromeLauncher.isPendingRelaunch(runningVersion: "150.0", diskVersion: nil))
        #expect(!ChromeLauncher.isPendingRelaunch(runningVersion: "", diskVersion: "151.0"))
    }
}

@Suite("Chrome Runtime Observation")
struct ChromeRuntimeObservationTests {
    // MARK: - Runtime process and relaunch window selection

    @Test("selects the newest live Chrome process")
    func selectsNewestProcess() {
        let candidates = [
            ChromeProcessCandidate(pid: 10, launchDate: Date(timeIntervalSince1970: 10)),
            ChromeProcessCandidate(pid: 20, launchDate: Date(timeIntervalSince1970: 20)),
            ChromeProcessCandidate(
                pid: 30, launchDate: Date(timeIntervalSince1970: 30), isTerminated: true),
        ]

        #expect(ChromeObservationPolicy.currentProcess(from: candidates)?.pid == 20)
    }

    @Test("relaunch matching subtracts restored fingerprints and keeps requested window")
    func relaunchFingerprintMatching() {
        let baseline = ["Mail|window", "Docs|window"]
        let current = ["Docs|window", "New App|window", "Mail|window"]

        #expect(
            ChromeObservationPolicy.candidateIndicesAfterRelaunch(
                chromeWasRunning: true,
                baselineFingerprints: baseline,
                currentFingerprints: current) == [1])
    }

    @Test("relaunch matching handles duplicate window fingerprints as a multiset")
    func relaunchDuplicateFingerprints() {
        let baseline = ["Untitled|window", "Untitled|window"]
        let current = ["Untitled|window", "Requested|window", "Untitled|window"]

        #expect(
            ChromeObservationPolicy.candidateIndicesAfterRelaunch(
                chromeWasRunning: true,
                baselineFingerprints: baseline,
                currentFingerprints: current) == [1])
    }

    @Test("cold launch treats every current window as a candidate")
    func coldLaunchCandidates() {
        #expect(
            ChromeObservationPolicy.candidateIndicesAfterRelaunch(
                chromeWasRunning: false,
                baselineFingerprints: ["Old"],
                currentFingerprints: ["First", "Second"]) == [0, 1])
    }

    @Test("parses framework version from lsof output")
    func parsesLsofOutput() {
        let output = """
            Chrome 42 user txt REG /usr/lib/libSystem.B.dylib
            Chrome 42 user txt REG /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/151.0.7922.76/Google Chrome Framework
            """
        #expect(ChromeLauncher.frameworkVersion(fromLsofOutput: output) == "151.0.7922.76")
    }
}
