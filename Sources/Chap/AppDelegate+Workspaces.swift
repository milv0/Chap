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
        for open in workspaceMenuItems(action: #selector(openWorkspaceFromMenu(_:))) {
            submenu.addItem(open)
        }
        if !workspaces.isEmpty { submenu.addItem(.separator()) }
        let capture = NSMenuItem(
            title: "Capture Workspace…", action: #selector(captureWorkspace), keyEquivalent: "")
        capture.target = self
        capture.isEnabled = workspaceLibrary.canAdd
        submenu.addItem(capture)
        if !workspaces.isEmpty {
            for (title, selector) in [
                ("Edit Workspace", #selector(editWorkspaceFromMenu(_:))),
                ("Remove Workspace", #selector(removeWorkspaceFromMenu(_:))),
            ] {
                let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let child = NSMenu()
                child.autoenablesItems = false
                for entry in workspaceMenuItems(action: selector) { child.addItem(entry) }
                parent.submenu = child
                submenu.addItem(parent)
            }
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    /// Workspace마다 하나씩, tag는 목록 인덱스. 메뉴는 목록이 바뀔 때마다 다시 만들어 tag가 늘 맞는다.
    private func workspaceMenuItems(action: Selector) -> [NSMenuItem] {
        workspaces.enumerated().map { index, workspace in
            let item = NSMenuItem(title: workspace.name, action: action, keyEquivalent: "")
            item.tag = index
            item.target = self
            return item
        }
    }

    /// 접근성 권한을 확인하고 없으면 상태 머신이 안내·프롬프트를 띄운다. 쓸 수 있으면 true.
    private func ensureWorkspaceAccessibility(reason: String) -> Bool {
        accessibilityController.refresh(reason: reason, showAlert: true, requestSystemPrompt: true)
        return AccessibilityPermission.isTrusted
    }

    @objc func captureWorkspace() {
        // 캡처 창을 띄우기 전에 읽어야 사용자가 보던 앞 앱이 그대로 잡힌다.
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let window = workspaceCaptureWindow, window.isVisible,
            let model = workspaceCaptureViewModel
        {
            // 열어 둔 채 창을 다시 배열했을 수 있으니 지금 화면을 다시 읽는다 (이름·선택은 유지).
            presentManagedWindow(window)
            model.beginReloading()
            WorkspaceCaptureService.capture(frontmostBundleIdentifier: frontmostBundleIdentifier) {
                [weak model] candidates in
                model?.finishLoading(candidates)
            }
            return
        }
        guard workspaceLibrary.canAdd else {
            WorkspaceAlert.show(
                message: "Four workspaces already saved",
                info: "Remove one before capturing another.")
            return
        }
        guard ensureWorkspaceAccessibility(reason: "workspace capture") else { return }

        let model = WorkspaceCaptureViewModel()
        model.displays = WorkspaceDisplay.connected()
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
        guard let workspace = workspaceLibrary.workspace(id: id) else { return }
        // 이미 하나가 열리는 중이면 조용히 무시한다. 버튼과 노치 줄이 진행 표시로 그 상태를 보여 준다.
        guard workspaceLibrary.busyID == nil else { return }
        guard ensureWorkspaceAccessibility(reason: "workspace restore") else { return }
        workspaceLibrary.busyID = workspace.id
        let started = WorkspaceRestoreService.restore(workspace) { [weak self] summary in
            self?.workspaceLibrary.busyID = nil
            guard summary.skipped > 0 else { return }
            WorkspaceAlert.show(
                message: "Couldn't place \(summary.skippedApps.joined(separator: ", "))",
                info: "The other \(summary.restored) window\(summary.restored == 1 ? "" : "s") "
                    + "are in place. A window Chap can't find for certain is left alone.")
        }
        if !started { workspaceLibrary.busyID = nil }
    }

    @objc private func openWorkspaceFromMenu(_ sender: NSMenuItem) {
        guard workspaces.indices.contains(sender.tag) else { return }
        let id = workspaces[sender.tag].id
        // 메뉴가 닫힌 다음 틱에 연다. 메뉴 추적 중에 다른 앱을 활성화하면 메뉴가 어긋난다.
        DispatchQueue.main.async { [weak self] in self?.openWorkspace(id: id) }
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

    /// 설정창 Launchers의 Workspaces 섹션을 연다. 저장된 Workspace가 있으면 첫 번째를 보여 주고,
    /// 없으면 섹션만 골라 "+"가 새 캡처를 뜻하게 한다.
    func showWorkspacesInSettings() {
        showSettings(focusing: nil)
        let first = workspaceLibrary.workspaces.first?.id
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SettingsView.focusWorkspace, object: first)
        }
    }

    /// 지금 화면에 있는 창 위치로 Workspace를 갱신한다. 같은 앱의 창만 바뀌고, 지금 없는 앱은 그대로 둔다.
    func updateWorkspacePositions(id: UUID) {
        guard let workspace = workspaceLibrary.workspace(id: id), workspaceLibrary.busyID == nil
        else { return }
        guard ensureWorkspaceAccessibility(reason: "workspace capture") else { return }
        workspaceLibrary.busyID = workspace.id
        WorkspaceCaptureService.capture(frontmostBundleIdentifier: nil) { [weak self] captured in
            guard let self else { return }
            self.workspaceLibrary.busyID = nil
            guard let current = self.workspaceLibrary.workspace(id: workspace.id) else { return }
            let result = current.updatingPositions(from: captured)
            guard result.updated > 0 else {
                WorkspaceAlert.show(
                    message: "No windows to update",
                    info: "Open this workspace's apps and arrange them, then try again.")
                return
            }
            guard
                self.workspaceLibrary.replace(
                    current.id, name: current.name, windows: result.workspace.windows)
            else { return }
            let missing = current.windows.count - result.updated
            if missing > 0 {
                WorkspaceAlert.show(
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
        guard let workspace = workspaceLibrary.workspace(id: id) else { return }
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
