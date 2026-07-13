import Testing

@testable import Chap

@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private let baseSites = [
        Site(name: "Google", url: "https://google.com", width: 800, height: 600, x: 0, y: 0)
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

    @Test func hasChangesDetectsSiteAddition() {
        let vm = SettingsViewModel(sites: baseSites)
        vm.sites.append(
            Site(name: "New", url: "https://new.com", width: 400, height: 300, x: 0, y: 0))
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

    @Test func onSaveCallbackReceivesCurrentState() {
        let vm = SettingsViewModel(sites: baseSites)
        var savedSites: [Site]?
        var savedGuide: Bool?
        var savedLogin: Bool?
        vm.onSave = { payload in
            savedSites = payload.sites
            savedGuide = payload.showGuideWindow
            savedLogin = payload.launchAtLogin
            return true
        }

        vm.sites.append(
            Site(name: "Added", url: "https://added.com", width: 300, height: 200, x: 10, y: 10))
        vm.showGuideWindow = false
        vm.launchAtLogin = true
        _ = vm.onSave?(SettingsPayload(sites: vm.sites, showGuideWindow: vm.showGuideWindow, launchAtLogin: vm.launchAtLogin))

        #expect(savedSites?.count == 2)
        #expect(savedGuide == false)
        #expect(savedLogin == true)
    }
}
