import Cocoa
import SwiftUI
import os

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var config: Config = Config(sites: [])
    let configPath = Defaults.configPath
    let configStore = ConfigStore()
    var settingsWindow: NSWindow?
    var qaWindow: NSWindow?
    var welcomeWindow: NSWindow?
    var settingsVM: SettingsViewModel?
    let globalHotKeyManager = GlobalHotKeyManager()
    lazy var accessibilityController = AccessibilityStateController(
        suppressesInteractivePrompts: isRunningTests)
    var isStatusMenuOpen = false
    var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    // MARK: - Managed windows (Settings / QA / Welcome)

    /// Settings/QA/Welcome 공용 관리 창 생성. delegate 연결과 재사용 가능 설정까지 담당.
    func makeManagedWindow(
        title: String, contentSize: NSSize, styleMask: NSWindow.StyleMask,
        minSize: NSSize? = nil
    ) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: EmptyView()))
        window.title = title
        window.styleMask = styleMask
        window.isReleasedWhenClosed = false
        window.setContentSize(contentSize)
        if let minSize { window.minSize = minSize }
        window.delegate = self
        return window
    }

    /// 관리 창을 앞으로 가져오고 Dock 아이콘을 활성화(.regular)한다.
    func presentManagedWindow(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Site opening

    @objc func openSite(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < config.sites.count else { return }
        launchSite(config.sites[index])
    }

    func launchSite(_ site: Site) {
        let needsAccessibility = site.launchType == .url || site.launchType == .app
        accessibilityController.refresh(reason: "launch", showAlert: needsAccessibility)

        var guideToken: Int?
        if config.showGuideWindow, site.launchType == .url, let screen = targetScreen(for: site) {
            let bounds = centeredBounds(for: site, on: screen)
            guideToken = GuideWindow.show(bounds: bounds)
        }

        switch site.launchType {
        case .url:
            ChromeLauncher.launch(site) {
                if let token = guideToken { GuideWindow.dismiss(token) }
            }
        case .app:
            AppLauncher.launch(site)
        case .finder:
            guard let path = site.folderPath, !path.isEmpty else {
                Log.launcher.error("No folder path configured for \(site.name, privacy: .private)")
                LauncherUtils.showAlert(message: "No folder path configured for \"\(site.name)\".")
                return
            }
            let expandedPath = NSString(string: path).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                Log.launcher.error("Folder not found: \(expandedPath, privacy: .private)")
                LauncherUtils.showAlert(message: "Folder not found: \(path)")
                return
            }
            guard let screen = targetScreen(for: site) else {
                // 사용 가능한 화면이 없으면 리사이즈 없이 폴더만 연다
                NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
                return
            }
            let bounds = centeredBounds(for: site, on: screen)
            FinderLauncher.openAndResize(
                path: expandedPath, bounds: (bounds.left, bounds.top, bounds.right, bounds.bottom))
        case .shell: ShellLauncher.launch(site)
        }
    }
}
