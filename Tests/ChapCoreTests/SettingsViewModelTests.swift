import Testing

@testable import Chap

@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private let baseSites = [
        Site(name: "Google", url: "https://google.com", width: 800, height: 600, x: 0, y: 0)
    ]

    @Test func hasChangesIsFalseInitially() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true)
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsSiteModification() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true)
        vm.sites[0].name = "Modified"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsBackgroundToggle() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true)
        vm.runInBackground = false
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsSiteAddition() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true)
        vm.sites.append(
            Site(name: "New", url: "https://new.com", width: 400, height: 300, x: 0, y: 0))
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsSiteRemoval() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true)
        vm.sites.removeAll()
        #expect(vm.hasChanges == true)
    }

    @Test func markSavedResetsHasChanges() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true)
        vm.sites[0].name = "Modified"
        #expect(vm.hasChanges == true)

        vm.markSaved()
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsGhostToggle() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true, showGhostWindow: true)
        vm.showGhostWindow = false
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsLoginToggle() {
        let vm = SettingsViewModel(
            sites: baseSites, runInBackground: true, showGhostWindow: true, launchAtLogin: false)
        vm.launchAtLogin = true
        #expect(vm.hasChanges == true)
    }

    @Test func onSaveCallbackReceivesCurrentState() {
        let vm = SettingsViewModel(sites: baseSites, runInBackground: true)
        var savedSites: [Site]?
        var savedBg: Bool?
        var savedGhost: Bool?
        var savedLogin: Bool?
        vm.onSave = { payload in
            savedSites = payload.sites
            savedBg = payload.runInBackground
            savedGhost = payload.showGhostWindow
            savedLogin = payload.launchAtLogin
        }

        vm.sites.append(
            Site(name: "Added", url: "https://added.com", width: 300, height: 200, x: 10, y: 10))
        vm.runInBackground = false
        vm.showGhostWindow = false
        vm.launchAtLogin = true
        vm.onSave?(SettingsPayload(sites: vm.sites, runInBackground: vm.runInBackground, showGhostWindow: vm.showGhostWindow, launchAtLogin: vm.launchAtLogin))

        #expect(savedSites?.count == 2)
        #expect(savedBg == false)
        #expect(savedGhost == false)
        #expect(savedLogin == true)
    }
}
