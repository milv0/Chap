import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import os

/// Handles config import/export/apply logic for SettingsView.
/// Uses ConfigImportProcessor for validation and display-matching on import.
enum SettingsConfigTransfer {

    // MARK: - Export

    /// Export current config to a user-chosen JSON file.
    /// Shows a validation error alert if the config is invalid for export.
    static func exportConfig(vm: SettingsViewModel) {
        let config = Config(
            showGuideWindow: vm.showGuideWindow, launchAtLogin: vm.launchAtLogin, sites: vm.sites)
        let validation = validateConfigForExport(config)
        guard validation.isValid else {
            let errorMessages = validation.errors.map { issue in
                let siteName =
                    issue.siteIndex < vm.sites.count ? vm.sites[issue.siteIndex].name : "?"
                return "• \(siteName): \(issue.message)"
            }.joined(separator: "\n")
            let alert = NSAlert()
            alert.messageText = "Cannot export config"
            alert.informativeText =
                "Please fix the following errors before exporting:\n\n\(errorMessages)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "chap.json"
        panel.directoryURL =
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            try encoder.encode(config).write(to: url, options: .atomic)
            Log.config.info("Config exported to \(url.path, privacy: .private)")
            let alert = NSAlert()
            alert.messageText = "Export successful"
            alert.informativeText = "Saved to \(url.path)"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - Import from File

    /// Present an open-panel and import the chosen JSON file.
    static func importConfig(vm: SettingsViewModel, onSuccess: (() -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            showImportError("Could not read file.")
            return
        }
        applyConfigData(data, vm: vm, onSuccess: onSuccess)
    }

    // MARK: - Import from URL (drag-and-drop)

    static func importFromURL(
        _ url: URL, vm: SettingsViewModel, onSuccess: (() -> Void)? = nil
    ) {
        guard let data = try? Data(contentsOf: url) else {
            showImportError("Could not read file.")
            return
        }
        applyConfigData(data, vm: vm, onSuccess: onSuccess)
    }

    // MARK: - Apply JSON String (Paste)

    /// Returns `true` on success (caller should dismiss sheet), `false` on failure
    /// (text and sheet stay open).
    @discardableResult
    static func applyJSONString(
        _ jsonString: String, vm: SettingsViewModel, onSuccess: (() -> Void)? = nil
    ) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            showImportError("The pasted text could not be converted to UTF-8.")
            return false
        }
        return applyConfigData(data, vm: vm, onSuccess: onSuccess)
    }

    // MARK: - Core Apply

    @discardableResult
    static func applyConfigData(
        _ data: Data, vm: SettingsViewModel, onSuccess: (() -> Void)? = nil
    ) -> Bool {
        let connectedDisplays = NSScreen.screens.map {
            DisplayMatchCandidate(identifier: displayUUID(for: $0), name: $0.localizedName)
        }

        switch ConfigImportProcessor.process(
            data: data, connectedDisplays: connectedDisplays)
        {
        case .decodeFailed(let detail):
            showImportError(detail)
            return false

        case .blocked(let sourceConfig, let issues):
            let issueMessages = issues.map { issue in
                let siteName =
                    issue.siteIndex < sourceConfig.sites.count
                    ? sourceConfig.sites[issue.siteIndex].name : "?"
                return "• \(siteName): \(issue.message)"
            }.joined(separator: "\n")
            let alert = NSAlert()
            alert.messageText = "Import blocked"
            alert.informativeText =
                "The following issues must be fixed before importing:\n\n\(issueMessages)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false

        case .success(let processed):
            vm.cancelPendingSave()
            let imported = processed.config
            let saved =
                vm.onSave?(
                    SettingsPayload(
                        sites: imported.sites,
                        showGuideWindow: imported.showGuideWindow,
                        launchAtLogin: imported.launchAtLogin)) ?? false
            guard saved else { return false }

            vm.sites = imported.sites
            vm.showGuideWindow = imported.showGuideWindow
            vm.launchAtLogin = imported.launchAtLogin
            vm.markSaved()
            onSuccess?()
            showImportSuccess(processed)
            return true
        }
    }

    // MARK: - Alerts

    static func showImportSuccess(_ processed: ProcessedConfigImport) {
        let sites = processed.config.sites
        let adjustmentLines = processed.fixes.map { fix in
            let siteName = fix.siteIndex < sites.count ? sites[fix.siteIndex].name : "?"
            return "• \(siteName): \(fix.message)"
        }
        let warningLines = processed.warnings.map { warning in
            let siteName = warning.siteIndex < sites.count ? sites[warning.siteIndex].name : "?"
            return "• \(siteName): \(warning.message)"
        }
        let alert = NSAlert()
        if adjustmentLines.isEmpty && warningLines.isEmpty {
            alert.messageText = "Import successful"
            alert.informativeText = "\(sites.count) site(s) loaded."
        } else {
            alert.messageText = "Import successful with adjustments"
            var sections = ["\(sites.count) site(s) loaded."]
            if !adjustmentLines.isEmpty {
                sections.append("Automatic fixes:\n\(adjustmentLines.joined(separator: "\n"))")
            }
            if !warningLines.isEmpty {
                sections.append("Display warnings:\n\(warningLines.joined(separator: "\n"))")
            }
            alert.informativeText = sections.joined(separator: "\n\n")
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func showImportError(_ detail: String) {
        let alert = NSAlert()
        alert.messageText = "Failed to import config."
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.runModal()
    }
}
