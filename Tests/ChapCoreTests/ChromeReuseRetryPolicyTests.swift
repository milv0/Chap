import Foundation
import Testing

@testable import Chap

@Suite("Chrome Reuse Retry Policy")
struct ChromeReuseRetryPolicyTests {
    @Test("first transient failure is retried")
    func firstTransientFailureRetries() {
        let retries = ChromeReuseRetryPolicy.shouldRetry(attempt: 0, isPermissionDenied: false)

        #expect(retries == true)
    }

    @Test("second failure is not retried (attempt cap)")
    func attemptCapStopsRetrying() {
        let retries = ChromeReuseRetryPolicy.shouldRetry(attempt: 1, isPermissionDenied: false)

        #expect(retries == false)
    }

    @Test("permission denial is never retried")
    func permissionDenialDoesNotRetry() {
        let retries = ChromeReuseRetryPolicy.shouldRetry(attempt: 0, isPermissionDenied: true)

        #expect(retries == false)
    }

    @Test("retry delay is short enough to stay unnoticeable")
    func retryDelayIsShort() {
        #expect(ChromeReuseRetryPolicy.retryDelayMicroseconds <= 500_000)
    }
}
