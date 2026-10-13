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

    /// 저장된 Workspace를 캡처 화면으로 고친다: 이름, 뺄 창, 창별 디스플레이.
    /// 창 위치·크기를 새로 잡으려면 창을 다시 배열한 뒤 새로 캡처한다.
    func editWorkspace(id: UUID) {
        guard let workspace = workspaces.first(where: { $0.id == id }) else { return }
        if let window = workspaceCaptureWindow, window.isVisible {
            presentManagedWindow(window)
            return
        }
        let model = WorkspaceCaptureViewModel()
        model.displays = NSScreen.screens.map {
            WorkspaceDisplay(identifier: displayUUID(for: $0), name: $0.localizedName)
        }
        model.finishLoading(workspace.windows)
        model.name = workspace.name
        let window = makeManagedWindow(
            title: "Edit Workspace", contentSize: NSSize(width: 520, height: 500),
            styleMask: [.titled, .closable])
        window.contentViewController = NSHostingController(
            rootView: WorkspaceCaptureView(
                model: model,
                title: "Edit Workspace",
                subtitle: "Rename it, leave out windows, or move them to another display.",
                onCancel: { [weak window] in window?.close() },
                onSave: { [weak self, weak window] name, windows in
                    guard let self else { return }
                    let updated = WorkspaceStore.replacing(
                        id, name: name, windows: windows, in: self.workspaces)
                    guard updated == self.workspaces || self.saveWorkspaces(updated) else {
                        return
                    }
                    window?.close()
                }))
        window.center()
        workspaceCaptureViewModel = model
        workspaceCaptureWindow = window
        presentManagedWindow(window)
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
