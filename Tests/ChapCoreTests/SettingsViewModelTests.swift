import Foundation
import Testing

@testable import Chap

@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private let baseSites = [
        Site(name: "Google", url: "https://google.com", width: 800, height: 600)
    ]

    @Test func hasChangesIsFalseInitially() {
        let vm = SettingsViewModel(sites: baseSites)
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsSiteModification() {
        let vm = SettingsViewModel(sites: baseSites)
        vm.sites[0].name = "Modified"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsURLWindowReuseToggle() {
        let vm = SettingsViewModel(sites: baseSites)
        vm.sites[0].reuseExistingWindow = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsSiteAddition() {
        let vm = SettingsViewModel(sites: baseSites)
        vm.sites.append(
            Site(name: "New", url: "https://new.com", width: 400, height: 300))
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsSiteRemoval() {
        let vm = SettingsViewModel(sites: baseSites)
        vm.sites.removeAll()
        #expect(vm.hasChanges == true)
    }

    @Test func markSavedResetsHasChanges() {
        let vm = SettingsViewModel(sites: baseSites)
        vm.sites[0].name = "Modified"
        #expect(vm.hasChanges == true)

        vm.markSaved()
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsGuideToggle() {
        let vm = SettingsViewModel(sites: baseSites, showGuideWindow: true)
        vm.showGuideWindow = false
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsLoginToggle() {
        let vm = SettingsViewModel(
            sites: baseSites, showGuideWindow: true, launchAtLogin: false)
        vm.launchAtLogin = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsOptionShortcutsToggle() {
        let vm = SettingsViewModel(sites: baseSites, optionShortcutsEnabled: true)
        vm.optionShortcutsEnabled = false
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsStatusBarIconChange() {
        let vm = SettingsViewModel(sites: baseSites, statusBarIcon: .default)
        vm.statusBarIcon = .lightning
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsNotchLauncherToggle() {
        let vm = SettingsViewModel(sites: baseSites, notchLauncherEnabled: false)
        vm.notchLauncherEnabled = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsNotchPanelStyleChange() {
        let vm = SettingsViewModel(sites: baseSites, notchPanelStyle: .black)
        vm.notchPanelStyle = .iceberg
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsNotchGlassAppearanceChange() {
        let vm = SettingsViewModel(sites: baseSites, notchGlassAppearance: .system)
        vm.notchGlassAppearance = .dark
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsNotchPanelOpacityChange() {
        let vm = SettingsViewModel(sites: baseSites, notchPanelOpacity: 0.6)
        vm.notchPanelOpacity = 0.9
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsNotchPanelColorChange() {
        let vm = SettingsViewModel(sites: baseSites, notchPanelColorHex: "#000000")
        vm.notchPanelColorHex = "#1A2B3C"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsNotchWidgetChange() {
        let vm = SettingsViewModel(sites: baseSites, notchWidgets: NotchWidget.defaultSlots)
        vm.notchWidgets[0] = .screenshots
        #expect(vm.hasChanges == true)
    }

    @Test func onSaveCallbackReceivesCurrentState() {
        let vm = SettingsViewModel(sites: baseSites)
        var savedSites: [Site]?
        var savedGuide: Bool?
        var savedLogin: Bool?
        var savedOptionShortcutsEnabled: Bool?
        var savedStatusBarIcon: StatusBarIconChoice?
        vm.onSave = { payload in
            savedSites = payload.sites
            savedGuide = payload.showGuideWindow
            savedLogin = payload.launchAtLogin
            savedOptionShortcutsEnabled = payload.optionShortcutsEnabled
            savedStatusBarIcon = payload.statusBarIcon
            return true
        }

        vm.sites.append(
            Site(name: "Added", url: "https://added.com", width: 300, height: 200))
        vm.showGuideWindow = false
        vm.launchAtLogin = true
        vm.optionShortcutsEnabled = false
        vm.statusBarIcon = .lightning
        _ = vm.onSave?(
            SettingsPayload(
                sites: vm.sites, showGuideWindow: vm.showGuideWindow,
                launchAtLogin: vm.launchAtLogin,
                optionShortcutsEnabled: vm.optionShortcutsEnabled,
                statusBarIcon: vm.statusBarIcon,
                hiddenMenuLaunchTypes: vm.hiddenMenuLaunchTypes,
                notchLauncherEnabled: vm.notchLauncherEnabled,
                notchPanelStyle: vm.notchPanelStyle,
                notchGlassAppearance: vm.notchGlassAppearance,
                notchPanelOpacity: vm.notchPanelOpacity,
                notchPanelColorHex: vm.notchPanelColorHex,
                notchWidgets: vm.notchWidgets))

        #expect(savedSites?.count == 2)
        #expect(savedGuide == false)
        #expect(savedLogin == true)
        #expect(savedOptionShortcutsEnabled == false)
        #expect(savedStatusBarIcon == .lightning)
    }

    @Test func scheduledAutoSavePersistsLatestValidState() {
        let queue = DispatchQueue(label: "SettingsViewModelTests.autoSave")
        let debouncer = SaveDebouncer(delay: 0.02, queue: queue)
        let vm = SettingsViewModel(sites: baseSites, saveDebouncer: debouncer)
        let saved = DispatchSemaphore(value: 0)
        var savedName: String?
        vm.onSave = { payload in
            savedName = payload.sites.first?.name
            saved.signal()
            return true
        }

        vm.sites[0].name = "First"
        vm.scheduleAutoSave()
        vm.sites[0].name = "Latest"
        vm.scheduleAutoSave()

        #expect(saved.wait(timeout: .now() + 1) == .success)
        // 세마포어는 onSave 안에서 신호되므로 markSaved 완료를 보장하지 않는다.
        // 큐를 비워 persist가 끝난 뒤에 검증한다.
        queue.sync {}
        #expect(savedName == "Latest")
        #expect(!vm.hasChanges)
    }

    @Test func scheduledAutoSaveSkipsInvalidState() {
        let queue = DispatchQueue(label: "SettingsViewModelTests.invalidAutoSave")
        let debouncer = SaveDebouncer(delay: 0.02, queue: queue)
        let vm = SettingsViewModel(sites: baseSites, saveDebouncer: debouncer)
        let unexpectedSave = DispatchSemaphore(value: 0)
        vm.onSave = { _ in
            unexpectedSave.signal()
            return true
        }

        vm.sites[0].name = ""
        vm.scheduleAutoSave()

        #expect(unexpectedSave.wait(timeout: .now() + 0.1) == .timedOut)
        #expect(vm.hasChanges)
    }
}
