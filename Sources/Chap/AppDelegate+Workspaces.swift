import Cocoa
import SwiftUI
import os

extension AppDelegate {
    func addWorkspacesMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "Workspaces", action: nil, keyEquivalent: "")
        item.image = NSImage(
            systemSymbolName: "rectangle.3.group", accessibilityDescription: "Workspaces")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for (index, workspace) in workspaces.enumerated() {
            let open = NSMenuItem(
                title: workspace.name, action: #selector(openWorkspaceFromMenu(_:)),
                keyEquivalent: "")
            open.tag = index
            open.target = self
            submenu.addItem(open)
        }
        if !workspaces.isEmpty { submenu.addItem(.separator()) }
        let capture = NSMenuItem(
            title: "Capture Workspace…", action: #selector(captureWorkspace), keyEquivalent: "")
        capture.target = self
        capture.isEnabled = workspaces.count < WorkspaceStore.maxWorkspaces
        submenu.addItem(capture)
        if !workspaces.isEmpty {
            let remove = NSMenuItem(title: "Remove Workspace", action: nil, keyEquivalent: "")
            let removeMenu = NSMenu()
            for (index, workspace) in workspaces.enumerated() {
                let removeItem = NSMenuItem(
                    title: workspace.name, action: #selector(removeWorkspaceFromMenu(_:)),
                    keyEquivalent: "")
                removeItem.tag = index
                removeItem.target = self
                removeMenu.addItem(removeItem)
            }
            remove.submenu = removeMenu
            submenu.addItem(remove)
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    @objc func captureWorkspace() {
        if let window = workspaceCaptureWindow, window.isVisible {
            presentManagedWindow(window)
            return
        }
        guard workspaces.count < WorkspaceStore.maxWorkspaces else {
            LauncherUtils.showAlert(
                message: "Four workspaces already saved",
                info: "Remove one before capturing another.")
            return
        }
        accessibilityController.refresh(
            reason: "workspace capture", showAlert: true, requestSystemPrompt: true)
        guard AccessibilityPermission.isTrusted else { return }

        let frontmostBundleIdentifier =
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let model = WorkspaceCaptureViewModel()
        model.displays = NSScreen.screens.map {
            WorkspaceDisplay(identifier: displayUUID(for: $0), name: $0.localizedName)
        }
        let window = makeManagedWindow(
            title: "Capture Workspace", contentSize: NSSize(width: 520, height: 500),
            styleMask: [.titled, .closable])
        window.contentViewController = NSHostingController(
            rootView: WorkspaceCaptureView(
                model: model,
                onCancel: { [weak window] in window?.close() },
                onSave: { [weak self, weak window] name, windows in
                    guard let self,
                        self.saveCapturedWorkspace(name: name, windows: windows)
                    else { return }
                    window?.close()
                }))
        window.center()
        workspaceCaptureViewModel = model
        workspaceCaptureWindow = window
        presentManagedWindow(window)
        WorkspaceCaptureService.capture(
            frontmostBundleIdentifier: frontmostBundleIdentifier
        ) { [weak model] candidates in
            model?.finishLoading(candidates)
        }
    }

    func openWorkspace(id: UUID) {
        guard let workspace = workspaces.first(where: { $0.id == id }) else { return }
        accessibilityController.refresh(
            reason: "workspace restore", showAlert: true, requestSystemPrompt: true)
        guard AccessibilityPermission.isTrusted else { return }
        let started = WorkspaceRestoreService.restore(workspace) { summary in
            guard summary.skipped > 0 else { return }
            LauncherUtils.showAlert(
                message: "Some windows stayed where they were",
                info: "Restored \(summary.restored) of \(summary.restored + summary.skipped).")
        }
        if !started {
            LauncherUtils.showAlert(message: "A workspace is already opening")
        }
    }

    @objc private func openWorkspaceFromMenu(_ sender: NSMenuItem) {
        guard workspaces.indices.contains(sender.tag) else { return }
        openWorkspace(id: workspaces[sender.tag].id)
    }

    @objc private func removeWorkspaceFromMenu(_ sender: NSMenuItem) {
        guard workspaces.indices.contains(sender.tag) else { return }
        let workspace = workspaces[sender.tag]
        let alert = NSAlert()
        alert.messageText = "Remove \"\(workspace.name)\"?"
        alert.informativeText = "The apps and their windows are not changed."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        saveWorkspaces(WorkspaceStore.removing(workspace.id, from: workspaces))
    }

    private func saveCapturedWorkspace(name: String, windows: [WorkspaceWindow]) -> Bool {
        let updated = WorkspaceStore.adding(name: name, windows: windows, to: workspaces)
        guard updated != workspaces else { return false }
        return saveWorkspaces(updated)
    }

    @discardableResult
    private func saveWorkspaces(_ updated: [ChapWorkspace]) -> Bool {
        do {
            try workspaceStore.save(updated)
            workspaces = updated
            buildMenu()
            return true
        } catch {
            Log.app.error(
                "Workspace save failed: \(error.localizedDescription, privacy: .public)")
            LauncherUtils.showAlert(
                message: "Workspace was not saved", info: error.localizedDescription)
            return false
        }
    }
}
