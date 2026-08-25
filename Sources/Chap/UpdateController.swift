import Cocoa
import Combine
import Sparkle
import os

/// Manages Sparkle's lifecycle with a **fail-closed** posture.
///
/// The controller starts Sparkle only when both `SUFeedURL` and `SUPublicEDKey`
/// are present and valid in the running bundle. With both values now embedded in
/// Info.plist, the updater starts and the "Check for Updates…" menu item is enabled.
/// Sparkle's built-in scheduler checks once per day when automatic checks are enabled.
///
/// Architecture:
/// - `SUEnableAutomaticChecks=true` enables daily checks without a permission prompt.
/// - Users can change Sparkle's persisted automatic-check preference in Settings.
/// - Manual checks remain available regardless of the automatic-check preference.
/// - Automatic download and installation are disabled; updates require confirmation.
/// - The EdDSA private key lives only in the operator's Keychain; only the public
///   key is shipped in the app.
final class UpdateController: ObservableObject {

    @Published private(set) var automaticallyChecksForUpdates = false

    /// Whether the updater has a valid configuration and is ready to check.
    var canCheckForUpdates: Bool {
        updaterController != nil
    }

    private var updaterController: SPUStandardUpdaterController?

    init() {
        guard !Self.isRunningTests else {
            Log.app.debug("Sparkle updater disabled during tests")
            return
        }
        guard UpdateConfiguration.isConfigured() else {
            Log.app.info(
                "Sparkle updater disabled: incomplete configuration (SUPublicEDKey not set)")
            return
        }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        self.updaterController = controller
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        Log.app.info(
            "Sparkle updater started (automatic checks: \(self.automaticallyChecksForUpdates))")
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard let controller = updaterController else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }

    /// Triggers a user-initiated update check.
    ///
    /// Does nothing if the configuration is incomplete.
    @objc func checkForUpdates(_ sender: Any?) {
        guard let controller = updaterController else {
            Log.app.debug("checkForUpdates called but updater is not configured")
            return
        }
        controller.checkForUpdates(sender)
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
