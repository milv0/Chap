import Foundation

/// Sparkle update configuration validation.
///
/// The updater adopts a **fail-closed** posture: unless both a non-empty
/// `SUFeedURL` and a non-empty `SUPublicEDKey` are present in the running
/// bundle's Info.plist, the update subsystem does not start, makes no network
/// requests, and the "Check for Updates…" menu item remains disabled.
///
/// This module is intentionally pure (no Sparkle import) so it can be tested
/// without invoking live networking or keychain access.
public enum UpdateConfiguration {

    /// The two values required for a secure update check.
    public struct Requirements {
        public let feedURL: String
        public let publicEDKey: String

        public init(feedURL: String, publicEDKey: String) {
            self.feedURL = feedURL
            self.publicEDKey = publicEDKey
        }
    }

    /// Validates that a complete, usable Sparkle configuration is present.
    ///
    /// Both `SUFeedURL` and `SUPublicEDKey` must be non-empty strings that
    /// represent real values (not placeholder text). The feed URL must be a
    /// valid HTTPS URL.
    ///
    /// - Parameter requirements: The pair of values to validate.
    /// - Returns: `true` only when the updater is safe to start.
    public static func isComplete(_ requirements: Requirements) -> Bool {
        guard !requirements.feedURL.isEmpty,
            !requirements.publicEDKey.isEmpty
        else { return false }

        // Feed URL must be a valid HTTPS endpoint
        guard let url = URL(string: requirements.feedURL),
            let scheme = url.scheme?.lowercased(),
            scheme == "https",
            url.host != nil
        else { return false }

        // Reject obvious placeholder keys
        let trimmed = requirements.publicEDKey.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "YOUR_PUBLIC_EDDSA_KEY_HERE" {
            return false
        }

        return true
    }

    /// Reads `SUFeedURL` and `SUPublicEDKey` from the given bundle's Info.plist.
    ///
    /// - Parameter bundle: The bundle to inspect (defaults to `.main`).
    /// - Returns: A `Requirements` value, or `nil` if either key is absent.
    public static func requirements(from bundle: Bundle = .main) -> Requirements? {
        guard let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else { return nil }
        return Requirements(feedURL: feedURL, publicEDKey: publicKey)
    }

    /// Whether the given bundle has a complete, valid Sparkle configuration.
    ///
    /// Convenience that combines `requirements(from:)` and `isComplete(_:)`.
    public static func isConfigured(in bundle: Bundle = .main) -> Bool {
        guard let reqs = requirements(from: bundle) else { return false }
        return isComplete(reqs)
    }
}
