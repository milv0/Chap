import Cocoa
import Sparkle
import os

/// Manages Sparkle's lifecycle with a **fail-closed** posture.
///
/// The controller starts Sparkle only when both `SUFeedURL` and `SUPublicEDKey`
/// are present and valid in the running bundle. With both values now embedded in
/// Info.plist, the updater starts and the "Check for Updates…" menu item is enabled.
/// `SUEnableAutomaticChecks=false` ensures no background polling or automatic-check
/// permission dialog occurs.
///
/// Architecture:
/// - Manual-only checks: `SUEnableAutomaticChecks` is set to `false` in Info.plist.
///   Starting the updater does not schedule background polling or show the
///   automatic-check permission dialog.
/// - The user triggers updates exclusively via the "Check for Updates…" menu item.
/// - The EdDSA private key lives only in the operator's Keychain; only the public
///   key is shipped in the app.
final class UpdateController {

    /// Whether the updater has a valid configuration and is ready to check.
    var canCheckForUpdates: Bool {
        updaterController != nil
    }

    private var updaterController: SPUStandardUpdaterController?

    init() {
        guard UpdateConfiguration.isConfigured() else {
            Log.app.info(
                "Sparkle updater disabled: incomplete configuration (SUPublicEDKey not set)")
            return
        }
        // SPUStandardUpdaterController respects SUEnableAutomaticChecks=false from Info.plist.
        // Starting the updater with automaticallyChecksForUpdates=false means it will never
        // schedule background polls or show the automatic-check permission prompt.
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        self.updaterController = controller
        Log.app.info("Sparkle updater started (manual-only, no automatic checks)")
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
}
