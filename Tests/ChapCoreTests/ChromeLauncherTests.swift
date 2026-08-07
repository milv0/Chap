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
