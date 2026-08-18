import Foundation
import Testing

@testable import Chap

// MARK: - Observation Policy Table (FLOW.md §7.2)

@Suite("App Observation Policy")
struct AppObservationPolicyTests {
    // MARK: - Normal app, running

    @Test("running normal app uses 8s timeout")
    func runningNormalTimeout() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.apple.Safari", appRunning: true)
        #expect(policy.timeout == 8.0)
    }

    @Test("running normal app uses 3s post-resize grace")
    func runningNormalGrace() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.apple.Safari", appRunning: true)
        #expect(policy.postResizeGrace == 3.0)
    }

    @Test("running normal app uses 0.2s focused fallback delay")
    func runningNormalFallbackDelay() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.apple.Safari", appRunning: true)
        #expect(policy.focusedFallbackDelay == 0.2)
    }

    @Test("running normal app is not Microsoft Office")
    func runningNormalNotOffice() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.apple.Safari", appRunning: true)
        #expect(!policy.isMicrosoftOffice)
    }

    // MARK: - Normal app, cold

    @Test("cold normal app uses 20s timeout")
    func coldNormalTimeout() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.apple.Safari", appRunning: false)
        #expect(policy.timeout == 20.0)
    }

    @Test("cold normal app uses 3s post-resize grace")
    func coldNormalGrace() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.apple.Safari", appRunning: false)
        #expect(policy.postResizeGrace == 3.0)
    }

    @Test("cold normal app uses timeout as focused fallback delay")
    func coldNormalFallbackDelayEqualsTimeout() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.apple.Safari", appRunning: false)
        #expect(policy.focusedFallbackDelay == policy.timeout)
    }

    // MARK: - Office app, running

    @Test("running Office app uses 30s timeout")
    func runningOfficeTimeout() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.microsoft.Excel", appRunning: true)
        #expect(policy.timeout == 30.0)
    }

    @Test("running Office app uses 20s post-resize grace")
    func runningOfficeGrace() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.microsoft.Excel", appRunning: true)
        #expect(policy.postResizeGrace == 20.0)
    }

    @Test("running Office app uses 0.2s focused fallback delay")
    func runningOfficeFallbackDelay() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.microsoft.Excel", appRunning: true)
        #expect(policy.focusedFallbackDelay == 0.2)
    }

    @Test("running Office app is flagged as Microsoft Office")
    func runningOfficeIsFlagged() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.microsoft.Excel", appRunning: true)
        #expect(policy.isMicrosoftOffice)
    }

    // MARK: - Office app, cold

    @Test("cold Office app uses 30s timeout")
    func coldOfficeTimeout() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.microsoft.Word", appRunning: false)
        #expect(policy.timeout == 30.0)
    }

    @Test("cold Office app uses 20s post-resize grace")
    func coldOfficeGrace() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.microsoft.Word", appRunning: false)
        #expect(policy.postResizeGrace == 20.0)
    }

    @Test("cold Office app uses timeout as focused fallback delay")
    func coldOfficeFallbackDelayEqualsTimeout() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: "com.microsoft.Word", appRunning: false)
        #expect(policy.focusedFallbackDelay == policy.timeout)
    }

    // MARK: - Office allowlist boundary cases

    @Test(
        "all four document-type Office bundle IDs are recognized",
        arguments: [
            "com.microsoft.Powerpoint",
            "com.microsoft.Excel",
            "com.microsoft.Word",
            "com.microsoft.onenote.mac",
        ])
    func allOfficeIdsRecognized(bundleId: String) {
        #expect(AppLauncher.isMicrosoftOfficeApp(bundleId: bundleId))
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: bundleId, appRunning: true)
        #expect(policy.isMicrosoftOffice)
    }

    @Test(
        "non-document Microsoft apps are NOT in Office allowlist",
        arguments: [
            "com.microsoft.teams2",
            "com.microsoft.Outlook",
            "com.microsoft.VSCode",
            "com.microsoft.edgemac",
        ])
    func nonDocumentMicrosoftAppsExcluded(bundleId: String) {
        #expect(!AppLauncher.isMicrosoftOfficeApp(bundleId: bundleId))
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: bundleId, appRunning: true)
        #expect(!policy.isMicrosoftOffice)
    }

    @Test("nil bundle ID produces a non-Office normal policy")
    func nilBundleIdIsNormal() {
        let policy = AppLauncher.resizeObservationPolicy(
            bundleId: nil, appRunning: true)
        #expect(!policy.isMicrosoftOffice)
        #expect(policy.timeout == 8.0)
    }

    @Test("PowerPoint bundle ID uses Powerpoint spelling (not PowerPoint)")
    func powerpointSpellingIsCorrect() {
        // The correct bundle ID uses lowercase 'p' in Powerpoint
        #expect(AppLauncher.isMicrosoftOfficeApp(bundleId: "com.microsoft.Powerpoint"))
        #expect(!AppLauncher.isMicrosoftOfficeApp(bundleId: "com.microsoft.PowerPoint"))
    }
}

// MARK: - Observation Registry (Token Supersession — Invariant I10)

@Suite("Resize Observation Registry")
struct ResizeObservationRegistryTests {
    @Test("first begin returns token 1")
    func firstTokenIsOne() {
        let registry = AppLauncher.ResizeObservationRegistry()
        let token = registry.begin(key: "app.test")
        #expect(token == 1)
    }

    @Test("successive begins increment the token")
    func tokenIncrements() {
        let registry = AppLauncher.ResizeObservationRegistry()
        let t1 = registry.begin(key: "app.test")
        let t2 = registry.begin(key: "app.test")
        let t3 = registry.begin(key: "app.test")

        #expect(t1 == 1)
        #expect(t2 == 2)
        #expect(t3 == 3)
    }

    @Test("only the latest token is current (supersession)")
    func latestTokenSupersedes() {
        let registry = AppLauncher.ResizeObservationRegistry()
        let t1 = registry.begin(key: "app.test")
        let t2 = registry.begin(key: "app.test")

        #expect(!registry.isCurrent(key: "app.test", token: t1))
        #expect(registry.isCurrent(key: "app.test", token: t2))
    }

    @Test("independent keys do not interfere")
    func independentKeys() {
        let registry = AppLauncher.ResizeObservationRegistry()
        let tExcel = registry.begin(key: "com.microsoft.Excel")
        let tWord = registry.begin(key: "com.microsoft.Word")

        #expect(registry.isCurrent(key: "com.microsoft.Excel", token: tExcel))
        #expect(registry.isCurrent(key: "com.microsoft.Word", token: tWord))
    }

    @Test("finish removes the key only when token matches")
    func finishOnlyMatchingToken() {
        let registry = AppLauncher.ResizeObservationRegistry()
        let t1 = registry.begin(key: "app.test")
        let t2 = registry.begin(key: "app.test")

        // Stale token finish should not remove the current entry
        registry.finish(key: "app.test", token: t1)
        #expect(registry.isCurrent(key: "app.test", token: t2))
    }

    @Test("finish with current token cleans up the key")
    func finishCurrentTokenCleansUp() {
        let registry = AppLauncher.ResizeObservationRegistry()
        let t1 = registry.begin(key: "app.test")
        registry.finish(key: "app.test", token: t1)

        // After cleanup, no token is current
        #expect(!registry.isCurrent(key: "app.test", token: t1))
    }

    @Test("new begin after finish restarts the token sequence")
    func beginAfterFinishRestartsToken() {
        let registry = AppLauncher.ResizeObservationRegistry()
        let t1 = registry.begin(key: "app.test")
        registry.finish(key: "app.test", token: t1)
        let t2 = registry.begin(key: "app.test")

        // finish removes the key; next begin starts fresh from 1
        #expect(t2 == 1)
        #expect(registry.isCurrent(key: "app.test", token: t2))
    }

    @Test("isCurrent returns false for unknown key")
    func unknownKeyIsNotCurrent() {
        let registry = AppLauncher.ResizeObservationRegistry()
        #expect(!registry.isCurrent(key: "never.registered", token: 1))
    }

    @Test("concurrent supersession scenario: rapid same-app launches")
    func rapidSameAppLaunchesSupersede() {
        let registry = AppLauncher.ResizeObservationRegistry()

        // Simulate rapid launches of the same app (Issue from FLOW.md I10)
        let t1 = registry.begin(key: "com.microsoft.Excel")
        let t2 = registry.begin(key: "com.microsoft.Excel")
        let t3 = registry.begin(key: "com.microsoft.Excel")

        // Only the last launch should be current
        #expect(!registry.isCurrent(key: "com.microsoft.Excel", token: t1))
        #expect(!registry.isCurrent(key: "com.microsoft.Excel", token: t2))
        #expect(registry.isCurrent(key: "com.microsoft.Excel", token: t3))

        // Finishing stale tokens should not affect the current one
        registry.finish(key: "com.microsoft.Excel", token: t1)
        registry.finish(key: "com.microsoft.Excel", token: t2)
        #expect(registry.isCurrent(key: "com.microsoft.Excel", token: t3))
    }
}

// MARK: - Observation Loop Termination Decisions

@Suite("Observation Loop Decisions")
struct ObservationLoopDecisionTests {
    // MARK: - shouldAttemptEarlyFocusedFallback

    @Test("fallback attempted when elapsed exceeds delay and not yet resized or attempted")
    func fallbackAttemptedWhenConditionsMet() {
        #expect(
            AppLauncher.shouldAttemptEarlyFocusedFallback(
                didResize: false, didAttemptAlready: false,
                elapsed: 0.3, focusedFallbackDelay: 0.2))
    }

    @Test("fallback NOT attempted when already resized")
    func noFallbackWhenAlreadyResized() {
        #expect(
            !AppLauncher.shouldAttemptEarlyFocusedFallback(
                didResize: true, didAttemptAlready: false,
                elapsed: 0.3, focusedFallbackDelay: 0.2))
    }

    @Test("fallback NOT attempted when already attempted (single-shot flag)")
    func noFallbackWhenAlreadyAttempted() {
        #expect(
            !AppLauncher.shouldAttemptEarlyFocusedFallback(
                didResize: false, didAttemptAlready: true,
                elapsed: 0.3, focusedFallbackDelay: 0.2))
    }

    @Test("fallback NOT attempted before the delay")
    func noFallbackBeforeDelay() {
        #expect(
            !AppLauncher.shouldAttemptEarlyFocusedFallback(
                didResize: false, didAttemptAlready: false,
                elapsed: 0.1, focusedFallbackDelay: 0.2))
    }

    @Test("fallback attempted exactly at the delay boundary")
    func fallbackAtExactBoundary() {
        #expect(
            AppLauncher.shouldAttemptEarlyFocusedFallback(
                didResize: false, didAttemptAlready: false,
                elapsed: 0.2, focusedFallbackDelay: 0.2))
    }

    @Test("cold app never triggers early fallback because delay == timeout")
    func coldAppNeverTriggersEarlyFallback() {
        // Regression: FLOW.md §12 Issue 1 explains cold apps don't hit this path
        // Cold app's focusedFallbackDelay == timeout, so elapsed can never
        // reach it within the loop (loop runs while elapsed < timeout)
        let timeout: TimeInterval = 20.0
        let coldDelay = AppLauncher.focusedFallbackDelay(
            appRunning: false, timeout: timeout)
        #expect(coldDelay == timeout)

        // At any elapsed < timeout, the condition should be false
        #expect(
            !AppLauncher.shouldAttemptEarlyFocusedFallback(
                didResize: false, didAttemptAlready: false,
                elapsed: timeout - 0.05, focusedFallbackDelay: coldDelay))
    }

    // MARK: - shouldEndObservationAfterFocusedFallback

    @Test("observation continues for Office even after successful focused fallback")
    func officeContinuesAfterFocusedFallback() {
        #expect(
            !AppLauncher.shouldEndObservationAfterFocusedFallback(
                didResize: true, isMicrosoftOffice: true))
    }

    @Test("observation ends for non-Office after successful focused fallback")
    func nonOfficeEndsAfterFocusedFallback() {
        #expect(
            AppLauncher.shouldEndObservationAfterFocusedFallback(
                didResize: true, isMicrosoftOffice: false))
    }

    @Test("observation never ends when focused fallback did not resize")
    func noEndWithoutResize() {
        #expect(
            !AppLauncher.shouldEndObservationAfterFocusedFallback(
                didResize: false, isMicrosoftOffice: false))
        #expect(
            !AppLauncher.shouldEndObservationAfterFocusedFallback(
                didResize: false, isMicrosoftOffice: true))
    }

    // MARK: - isGracePeriodExpired

    @Test("grace not expired when no resize happened")
    func graceNotExpiredWithoutResize() {
        #expect(
            !AppLauncher.isGracePeriodExpired(
                lastResizeTime: nil, now: 100.0, postResizeGrace: 3.0))
    }

    @Test("grace not expired when within grace period")
    func graceNotExpiredWithinPeriod() {
        #expect(
            !AppLauncher.isGracePeriodExpired(
                lastResizeTime: 100.0, now: 102.5, postResizeGrace: 3.0))
    }

    @Test("grace expired exactly at boundary")
    func graceExpiredAtBoundary() {
        #expect(
            AppLauncher.isGracePeriodExpired(
                lastResizeTime: 100.0, now: 103.0, postResizeGrace: 3.0))
    }

    @Test("grace expired well past boundary")
    func graceExpiredPastBoundary() {
        #expect(
            AppLauncher.isGracePeriodExpired(
                lastResizeTime: 100.0, now: 110.0, postResizeGrace: 3.0))
    }

    @Test("Office 20s grace keeps observation alive during startup transition")
    func officeGraceKeepsObservation() {
        // Simulates: resize at T=2s, now at T=15s, grace=20s → still observing
        #expect(
            !AppLauncher.isGracePeriodExpired(
                lastResizeTime: 2.0, now: 15.0, postResizeGrace: 20.0))
    }

    @Test("no resize means grace never triggers loop exit")
    func noResizeMeansNoGraceExit() {
        // FLOW.md §12 Issue 1: without resize, loop runs to deadline
        // When lastResizeTime is nil, the grace check cannot end the loop.
        // The loop runs until hardDeadline, reproducing the 30s spin.
        #expect(
            !AppLauncher.isGracePeriodExpired(
                lastResizeTime: nil, now: 29.9, postResizeGrace: 3.0))
        #expect(
            !AppLauncher.isGracePeriodExpired(
                lastResizeTime: nil, now: 29.9, postResizeGrace: 20.0))
    }

    // MARK: - canResizeNewWindow

    @Test("non-Office can resize when no prior resize happened")
    func nonOfficeCanResizeFirst() {
        #expect(
            AppLauncher.canResizeNewWindow(
                isMicrosoftOffice: false, alreadyResized: false))
    }

    @Test("non-Office cannot resize once already resized")
    func nonOfficeCannotResizeSecond() {
        #expect(
            !AppLauncher.canResizeNewWindow(
                isMicrosoftOffice: false, alreadyResized: true))
    }

    @Test("Office can always resize new windows (replacement policy)")
    func officeCanAlwaysResize() {
        #expect(
            AppLauncher.canResizeNewWindow(
                isMicrosoftOffice: true, alreadyResized: false))
        #expect(
            AppLauncher.canResizeNewWindow(
                isMicrosoftOffice: true, alreadyResized: true))
    }
}

// MARK: - Window Eligibility (extended edge cases)

@Suite("Window Eligibility Extended")
struct WindowEligibilityExtendedTests {
    @Test("window without AXWindow role is rejected regardless of settable attributes")
    func nonWindowRoleRejected() {
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: "AXSheet", subrole: "AXStandardWindow",
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: false))
    }

    @Test("nil role is rejected")
    func nilRoleRejected() {
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: nil, subrole: "AXStandardWindow",
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: false))
    }

    @Test("window that cannot move is rejected")
    func cannotMoveRejected() {
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: "AXStandardWindow",
                canSetPosition: false, canSetSize: true, isMicrosoftOffice: false))
    }

    @Test("Office AXDialog subrole is eligible (resizable non-standard)")
    func officeDialogEligible() {
        #expect(
            AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: "AXDialog",
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: true))
    }

    @Test("non-Office AXDialog subrole is rejected")
    func nonOfficeDialogRejected() {
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: "AXDialog",
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: false))
    }

    @Test("nil subrole is treated as non-standard (only Office eligible)")
    func nilSubroleOnlyOfficeEligible() {
        #expect(
            AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: nil,
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: true))
        #expect(
            !AppLauncher.isEligibleWindowMetadata(
                role: "AXWindow", subrole: nil,
                canSetPosition: true, canSetSize: true, isMicrosoftOffice: false))
    }
}
