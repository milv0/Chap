import Foundation
import Testing

@testable import Chap

@Suite("UpdateConfiguration – fail-closed validation")
struct UpdateConfigurationTests {

    // MARK: - Complete / valid configurations

    @Test func completeConfigurationIsValid() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://milv0.github.io/Chap/appcast.xml",
            publicEDKey: "dGhpcyBpcyBhIHJlYWwga2V5")
        #expect(UpdateConfiguration.isComplete(reqs))
    }

    @Test func validHTTPSURLWithKey() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://example.com/appcast.xml",
            publicEDKey: "abc123def456")
        #expect(UpdateConfiguration.isComplete(reqs))
    }

    // MARK: - Missing or empty values (fail closed)

    @Test func emptyFeedURLIsIncomplete() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "",
            publicEDKey: "someKey123")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    @Test func emptyPublicKeyIsIncomplete() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://example.com/appcast.xml",
            publicEDKey: "")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    @Test func bothEmptyIsIncomplete() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "",
            publicEDKey: "")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    // MARK: - Invalid feed URLs (fail closed)

    @Test func httpFeedURLIsRejected() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "http://example.com/appcast.xml",
            publicEDKey: "validKey123")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    @Test func malformedURLIsRejected() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "not a url",
            publicEDKey: "validKey123")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    @Test func fileURLIsRejected() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "file:///tmp/appcast.xml",
            publicEDKey: "validKey123")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    @Test func urlWithoutHostIsRejected() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://",
            publicEDKey: "validKey123")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    // MARK: - Placeholder keys (fail closed)

    @Test func placeholderKeyIsRejected() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://example.com/appcast.xml",
            publicEDKey: "YOUR_PUBLIC_EDDSA_KEY_HERE")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    @Test func whitespaceOnlyKeyIsRejected() {
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://example.com/appcast.xml",
            publicEDKey: "   ")
        #expect(!UpdateConfiguration.isComplete(reqs))
    }

    // MARK: - Shipped public key validation

    @Test func shippedPublicKeyIsAccepted() {
        // The actual EdDSA public key embedded in Info.plist
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://milv0.github.io/Chap/appcast.xml",
            publicEDKey: "3RRsmvZE5JAXnPjxynxsphkCltJtZb9ldZb/HjsZyJM=")
        #expect(UpdateConfiguration.isComplete(reqs))
    }

    @Test func shippedFeedURLAndKeyFormValidConfiguration() {
        // Verify the exact combination shipped in project.yml is valid
        let reqs = UpdateConfiguration.Requirements(
            feedURL: "https://milv0.github.io/Chap/appcast.xml",
            publicEDKey: "3RRsmvZE5JAXnPjxynxsphkCltJtZb9ldZb/HjsZyJM=")
        #expect(UpdateConfiguration.isComplete(reqs))
        #expect(!reqs.feedURL.isEmpty)
        #expect(!reqs.publicEDKey.isEmpty)
    }

    // MARK: - Bundle extraction

    @Test func requirementsFromAppBundleReturnsValues() {
        // The app bundle now includes both SUFeedURL and SUPublicEDKey
        let reqs = UpdateConfiguration.requirements(from: Bundle(for: AppDelegate.self))
        #expect(reqs != nil)
        #expect(reqs?.feedURL == "https://milv0.github.io/Chap/appcast.xml")
        #expect(reqs?.publicEDKey == "3RRsmvZE5JAXnPjxynxsphkCltJtZb9ldZb/HjsZyJM=")
    }

    @Test func isConfiguredReturnsTrueWithShippedKey() {
        // App bundle now has both SUFeedURL and SUPublicEDKey
        #expect(UpdateConfiguration.isConfigured(in: Bundle(for: AppDelegate.self)))
    }
}
