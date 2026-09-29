import Testing

@testable import Chap

@Suite("Global Hot Key Registrations")
struct GlobalHotKeyManagerTests {
    @Test("fixed shortcuts precede configured site shortcuts")
    func fixedShortcutsPrecedeSiteShortcuts() {
        let sites = [
            site(name: "A", shortcut: "G"),
            site(name: "B", shortcut: nil),
            site(name: "C", shortcut: "T"),
        ]

        let registrations = globalHotKeyRegistrations(
            for: sites, optionShortcutsEnabled: true)

        #expect(
            registrations == [
                GlobalHotKeyRegistration(character: ".", action: .openMenu),
                GlobalHotKeyRegistration(character: ",", action: .openSettings),
                GlobalHotKeyRegistration(character: "G", action: .launchSite(index: 0)),
                GlobalHotKeyRegistration(character: "T", action: .launchSite(index: 2)),
            ])
    }

    @Test("invalid and duplicate shortcuts are omitted")
    func invalidShortcutsAreOmitted() {
        let sites = [
            site(name: "A", shortcut: "."),
            site(name: "B", shortcut: "AB"),
            site(name: "C", shortcut: "G"),
            site(name: "D", shortcut: "g"),
        ]

        let registrations = globalHotKeyRegistrations(
            for: sites, optionShortcutsEnabled: true)

        #expect(
            registrations == [
                GlobalHotKeyRegistration(character: ".", action: .openMenu),
                GlobalHotKeyRegistration(character: ",", action: .openSettings),
                GlobalHotKeyRegistration(character: "G", action: .launchSite(index: 2)),
            ])
    }

    @Test("disabled Option shortcuts produce no registrations")
    func disabledOptionShortcutsProduceNoRegistrations() {
        let registrations = globalHotKeyRegistrations(
            for: [site(name: "A", shortcut: "G")],
            optionShortcutsEnabled: false)

        #expect(registrations.isEmpty)
    }

    private func site(name: String, shortcut: String?) -> Site {
        Site(
            name: name,
            url: "https://\(name.lowercased()).com",
            width: 800,
            height: 600,
            shortcut: shortcut)
    }
}
