import Cocoa
import SwiftUI
import os

extension AppDelegate {
    var layouts: [ChapLayout] { layoutLibrary.layouts }

    func addLayoutsMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "Layouts", action: nil, keyEquivalent: "")
        item.image = NSImage(
            systemSymbolName: "rectangle.3.group", accessibilityDescription: "Layouts")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for open in layoutMenuItems(action: #selector(openLayoutFromMenu(_:))) {
            submenu.addItem(open)
        }
        if !layouts.isEmpty { submenu.addItem(.separator()) }
        let capture = NSMenuItem(
            title: "Capture Layout…", action: #selector(captureLayout), keyEquivalent: "")
        capture.target = self
        capture.isEnabled = layoutLibrary.canAdd
        submenu.addItem(capture)
        if !layouts.isEmpty {
            // 고치기·지우기는 설정의 Layouts 섹션 한곳에서 한다(메뉴를 3단으로 타지 않게).
            let edit = NSMenuItem(
                title: "Edit Layouts…", action: #selector(editLayoutsFromMenu), keyEquivalent: "")
            edit.target = self
            submenu.addItem(edit)
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    /// Layout마다 하나씩, tag는 목록 인덱스. 메뉴는 목록이 바뀔 때마다 다시 만들어 tag가 늘 맞는다.
    private func layoutMenuItems(action: Selector) -> [NSMenuItem] {
        layouts.enumerated().map { index, layout in
            let item = NSMenuItem(title: layout.name, action: action, keyEquivalent: "")
            item.tag = index
            item.target = self
            return item
        }
    }

    /// 접근성 권한을 확인하고 없으면 상태 머신이 안내·프롬프트를 띄운다. 쓸 수 있으면 true.
    private func ensureLayoutAccessibility(reason: String) -> Bool {
        accessibilityController.refresh(reason: reason, showAlert: true, requestSystemPrompt: true)
        return AccessibilityPermission.isTrusted
    }

    @objc func captureLayout() {
        // 캡처 창을 띄우기 전에 읽어야 사용자가 보던 앞 앱이 그대로 잡힌다.
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let window = layoutCaptureWindow, window.isVisible,
            let model = layoutCaptureViewModel
        {
            // 열어 둔 채 창을 다시 배열했을 수 있으니 지금 화면을 다시 읽는다 (이름·선택은 유지).
            presentManagedWindow(window)
            model.beginReloading()
            LayoutCaptureService.capture(frontmostBundleIdentifier: frontmostBundleIdentifier) {
                [weak model] candidates in
                model?.finishLoading(candidates)
            }
            return
        }
        guard layoutLibrary.canAdd else {
            LayoutAlert.show(
                message: "Four layouts already saved",
                info: "Remove one before capturing another.")
            return
        }
        guard ensureLayoutAccessibility(reason: "layout capture") else { return }

        let model = LayoutCaptureViewModel()
        model.displays = LayoutDisplay.connected()
        let window = makeManagedWindow(
            title: "Capture Layout", contentSize: NSSize(width: 520, height: 500),
            styleMask: [.titled, .closable])
        window.contentViewController = NSHostingController(
            rootView: LayoutCaptureView(
                model: model,
                onCancel: { [weak window] in window?.close() },
                onSave: { [weak self, weak window] name, windows in
                    guard let self,
                        self.saveCapturedLayout(name: name, windows: windows)
                    else { return }
                    window?.close()
                }))
        window.center()
        layoutCaptureViewModel = model
        layoutCaptureWindow = window
        presentManagedWindow(window)
        LayoutCaptureService.capture(
            frontmostBundleIdentifier: frontmostBundleIdentifier
        ) { [weak model] candidates in
            model?.finishLoading(candidates)
        }
    }

    func openLayout(id: UUID) {
        guard let layout = layoutLibrary.layout(id: id) else { return }
        // 이미 하나가 열리는 중이면 조용히 무시한다. 버튼과 노치 줄이 진행 표시로 그 상태를 보여 준다.
        guard layoutLibrary.busyID == nil else { return }
        guard ensureLayoutAccessibility(reason: "layout restore") else { return }
        layoutLibrary.busyID = layout.id
        let started = LayoutRestoreService.restore(layout) { [weak self] summary in
            self?.layoutLibrary.busyID = nil
            guard summary.skipped > 0 else { return }
            LayoutAlert.show(
                message: "Couldn't place \(summary.skippedApps.joined(separator: ", "))",
                info: "The other \(summary.restored) window\(summary.restored == 1 ? "" : "s") "
                    + "are in place. A window Chap can't find for certain is left alone.")
        }
        if !started { layoutLibrary.busyID = nil }
    }

    @objc private func openLayoutFromMenu(_ sender: NSMenuItem) {
        guard layouts.indices.contains(sender.tag) else { return }
        let id = layouts[sender.tag].id
        // 메뉴가 닫힌 다음 틱에 연다. 메뉴 추적 중에 다른 앱을 활성화하면 메뉴가 어긋난다.
        DispatchQueue.main.async { [weak self] in self?.openLayout(id: id) }
    }

    /// 메뉴 Edit Layouts…: 메뉴가 닫힌 다음 틱에 설정의 Layouts 섹션을 연다.
    @objc private func editLayoutsFromMenu() {
        DispatchQueue.main.async { [weak self] in self?.showLayoutsInSettings() }
    }

    /// 저장된 Layout을 설정창 Launchers의 Layouts 섹션에서 연다(고치는 곳은 한 군데다).
    func editLayout(id: UUID) {
        guard layoutLibrary.layout(id: id) != nil else { return }
        showSettings(focusing: nil)
        // 새 창이면 SettingsView가 구독을 마친 다음 틱에 전달한다.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SettingsView.focusLayout, object: id)
        }
    }

    /// 설정창 Launchers의 Layouts 섹션을 연다. 저장된 Layout이 있으면 첫 번째를 보여 주고,
    /// 없으면 섹션만 골라 "+"가 새 캡처를 뜻하게 한다.
    func showLayoutsInSettings() {
        showSettings(focusing: nil)
        let first = layoutLibrary.layouts.first?.id
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SettingsView.focusLayout, object: first)
        }
    }

    /// 지금 화면에 있는 창 위치로 Layout을 갱신한다. 같은 앱의 창만 바뀌고, 지금 없는 앱은 그대로 둔다.
    func updateLayoutPositions(id: UUID) {
        guard let layout = layoutLibrary.layout(id: id), layoutLibrary.busyID == nil
        else { return }
        guard ensureLayoutAccessibility(reason: "layout capture") else { return }
        layoutLibrary.busyID = layout.id
        LayoutCaptureService.capture(frontmostBundleIdentifier: nil) { [weak self] captured in
            guard let self else { return }
            self.layoutLibrary.busyID = nil
            guard let current = self.layoutLibrary.layout(id: layout.id) else { return }
            let result = current.updatingPositions(from: captured)
            guard result.updated > 0 else {
                LayoutAlert.show(
                    message: "No windows to update",
                    info: "Open this layout's apps and arrange them, then try again.")
                return
            }
            guard
                self.layoutLibrary.replace(
                    current.id, name: current.name, windows: result.layout.windows)
            else { return }
            let missing = current.windows.count - result.updated
            if missing > 0 {
                LayoutAlert.show(
                    message: "Updated \(result.updated) of \(current.windows.count) windows",
                    info: "Apps that weren't open kept their saved positions.")
            }
        }
    }

    /// 확인 후 Layout을 지운다. 설정과 노치 우클릭이 같은 경로를 쓴다.
    func confirmRemoveLayout(id: UUID) {
        guard let layout = layoutLibrary.layout(id: id) else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \"\(layout.name)\"?"
        alert.informativeText = "The apps and their windows are not changed."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.buttons.first?.hasDestructiveAction = true
        // accessory 앱은 활성화하지 않으면 확인 창이 앞 앱 뒤에 열려 아무 일도 없는 것처럼 보인다.
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        layoutLibrary.remove(layout.id)
    }

    private func saveCapturedLayout(name: String, windows: [LayoutWindow]) -> Bool {
        guard let id = layoutLibrary.add(name: name, windows: windows) else { return false }
        // 저장한 Layout은 바로 고칠 수 있게 설정창이 열려 있으면 그 자리를 보여 준다.
        if settingsWindow?.isVisible == true {
            NotificationCenter.default.post(name: SettingsView.focusLayout, object: id)
        }
        return true
    }
}
