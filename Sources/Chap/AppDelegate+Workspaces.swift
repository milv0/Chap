import Cocoa
import SwiftUI
import os

extension AppDelegate {
    var workspaces: [ChapWorkspace] { workspaceLibrary.workspaces }

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
            let edit = NSMenuItem(title: "Edit Workspace", action: nil, keyEquivalent: "")
            let editMenu = NSMenu()
            editMenu.autoenablesItems = false
            for (index, workspace) in workspaces.enumerated() {
                let editItem = NSMenuItem(
                    title: workspace.name, action: #selector(editWorkspaceFromMenu(_:)),
                    keyEquivalent: "")
                editItem.tag = index
                editItem.target = self
                editMenu.addItem(editItem)
            }
            edit.submenu = editMenu
            submenu.addItem(edit)
            let remove = NSMenuItem(title: "Remove Workspace", action: nil, keyEquivalent: "")
            let removeMenu = NSMenu()
            removeMenu.autoenablesItems = false
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

    @objc private func editWorkspaceFromMenu(_ sender: NSMenuItem) {
        guard workspaces.indices.contains(sender.tag) else { return }
        let id = workspaces[sender.tag].id
        DispatchQueue.main.async { [weak self] in self?.editWorkspace(id: id) }
    }

    /// 저장된 Workspace를 설정창 Launchers의 Workspaces 섹션에서 연다(고치는 곳은 한 군데다).
    func editWorkspace(id: UUID) {
        guard workspaceLibrary.workspace(id: id) != nil else { return }
        showSettings(focusing: nil)
        // 새 창이면 SettingsView가 구독을 마친 다음 틱에 전달한다.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SettingsView.focusWorkspace, object: id)
        }
    }

    /// 지금 화면에 있는 창 위치로 Workspace를 갱신한다. 같은 앱의 창만 바뀌고, 지금 없는 앱은 그대로 둔다.
    func updateWorkspacePositions(id: UUID) {
        guard let workspace = workspaceLibrary.workspace(id: id) else { return }
        accessibilityController.refresh(
            reason: "workspace capture", showAlert: true, requestSystemPrompt: true)
        guard AccessibilityPermission.isTrusted else { return }
        WorkspaceCaptureService.capture(frontmostBundleIdentifier: nil) { [weak self] captured in
            guard let self, let current = self.workspaceLibrary.workspace(id: workspace.id)
            else { return }
            let result = current.updatingPositions(from: captured)
            guard result.updated > 0 else {
                LauncherUtils.showAlert(
                    message: "No windows to update",
                    info: "Open the workspace's apps and arrange them, then try again.")
                return
            }
            self.workspaceLibrary.replace(
                current.id, name: current.name, windows: result.workspace.windows)
            let missing = current.windows.count - result.updated
            if missing > 0 {
                LauncherUtils.showAlert(
                    message: "Updated \(result.updated) of \(current.windows.count) windows",
                    info: "Apps that weren't open kept their saved positions.")
            }
        }
    }

    @objc private func removeWorkspaceFromMenu(_ sender: NSMenuItem) {
        guard workspaces.indices.contains(sender.tag) else { return }
        let id = workspaces[sender.tag].id
        // 메뉴가 완전히 닫힌 다음 틱에 묻는다. 메뉴 추적 중에 띄운 모달은 뜨지 않거나 다른 앱 뒤에 숨는다.
        DispatchQueue.main.async { [weak self] in self?.confirmRemoveWorkspace(id: id) }
    }

    /// 확인 후 Workspace를 지운다. 메뉴와 노치 우클릭이 같은 경로를 쓴다.
    func confirmRemoveWorkspace(id: UUID) {
        guard let workspace = workspaces.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \"\(workspace.name)\"?"
        alert.informativeText = "The apps and their windows are not changed."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.buttons.first?.hasDestructiveAction = true
        // accessory 앱은 활성화하지 않으면 확인 창이 앞 앱 뒤에 열려 아무 일도 없는 것처럼 보인다.
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        workspaceLibrary.remove(workspace.id)
    }

    private func saveCapturedWorkspace(name: String, windows: [WorkspaceWindow]) -> Bool {
        guard let id = workspaceLibrary.add(name: name, windows: windows) else { return false }
        // 저장한 Workspace는 바로 고칠 수 있게 설정창이 열려 있으면 그 자리를 보여 준다.
        if settingsWindow?.isVisible == true {
            NotificationCenter.default.post(name: SettingsView.focusWorkspace, object: id)
        }
        return true
    }
}
