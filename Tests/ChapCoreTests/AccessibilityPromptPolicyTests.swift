import Testing

@testable import Chap

@Suite("Accessibility prompt policy")
struct AccessibilityPromptPolicyTests {
    @Test("requests after interactive onboarding only when access is not granted")
    func requestsOnlyForUntrustedInteractiveApp() {
        #expect(
            AccessibilityPromptPolicy.shouldRequestAfterOnboarding(
                isTrusted: false,
                suppressesInteractivePrompts: false))
        #expect(
            !AccessibilityPromptPolicy.shouldRequestAfterOnboarding(
                isTrusted: true,
                suppressesInteractivePrompts: false))
        #expect(
            !AccessibilityPromptPolicy.shouldRequestAfterOnboarding(
                isTrusted: false,
                suppressesInteractivePrompts: true))
    }

    @Test("requests at launch when access is not granted, even without onboarding")
    func requestsAtLaunchForUntrustedInteractiveApp() {
        #expect(
            AccessibilityPromptPolicy.shouldRequestAtLaunch(
                isTrusted: false,
                suppressesInteractivePrompts: false))
        #expect(
            !AccessibilityPromptPolicy.shouldRequestAtLaunch(
                isTrusted: true,
                suppressesInteractivePrompts: false))
        #expect(
            !AccessibilityPromptPolicy.shouldRequestAtLaunch(
                isTrusted: false,
                suppressesInteractivePrompts: true))
    }
}
