import Foundation
import Testing

@testable import Chap

@Suite("Quick Note shortcut")
struct QuickNoteShortcutTests {
    private func site(_ name: String, _ shortcut: String?) -> Site {
        Site(
            name: name, url: "https://example.com/\(name)", width: 800, height: 600,
            shortcut: shortcut)
    }

    @Test("input becomes one uppercase key, or off when empty")
    func normalizes() {
        #expect(QuickNoteShortcutPolicy.normalized("n") == "N")
        #expect(QuickNoteShortcutPolicy.normalized("  q ") == "Q")
        #expect(QuickNoteShortcutPolicy.normalized("") == nil)
        #expect(QuickNoteShortcutPolicy.normalized("   ") == nil)
        #expect(QuickNoteShortcutPolicy.normalized(nil) == nil)
    }

    @Test("site shortcuts and reserved keys win over Quick Note")
    func conflicts() {
        let sites = [site("Notes", "n"), site("Docs", "D")]
        #expect(QuickNoteShortcutPolicy.conflict(for: "N", sites: sites) == .site(name: "Notes"))
        #expect(QuickNoteShortcutPolicy.conflict(for: ".", sites: sites) == .reserved)
        #expect(QuickNoteShortcutPolicy.conflict(for: "Q", sites: sites) == nil)
        #expect(QuickNoteShortcutPolicy.conflict(for: nil, sites: sites) == nil)
    }

    @Test("the key is registered only with the notch and the note icon on, and no conflict")
    func registeredKey() {
        func key(_ shortcut: String?, notch: Bool = true, note: Bool = true, sites: [Site] = [])
            -> String?
        {
            QuickNoteShortcutPolicy.registeredKey(
                shortcut: shortcut, notchLauncherEnabled: notch, quickNoteEnabled: note,
                sites: sites)
        }
        #expect(key("N") == "N")
        #expect(key("N", notch: false) == nil)
        #expect(key("N", note: false) == nil)
        #expect(key(nil) == nil)
        #expect(key("N", sites: [site("Notes", "N")]) == nil)
    }

    @Test("older configs get ⌥N; an empty value stays off; the key round-trips")
    func configDecoding() throws {
        let missing = try JSONDecoder().decode(Config.self, from: Data(#"{"sites": []}"#.utf8))
        #expect(missing.notchQuickNoteShortcut == "N")

        let off = try JSONDecoder().decode(
            Config.self, from: Data(#"{"notchQuickNoteShortcut": "", "sites": []}"#.utf8))
        #expect(off.notchQuickNoteShortcut == nil)

        for value in ["Q", nil] as [String?] {
            let config = Config(notchQuickNoteShortcut: value, sites: [])
            let decoded = try JSONDecoder().decode(
                Config.self, from: JSONEncoder().encode(config))
            #expect(decoded.notchQuickNoteShortcut == value)
        }
    }

    @Test("⌥key registers after the site shortcuts")
    func hotKeyRegistration() {
        let registrations = globalHotKeyRegistrations(
            for: [site("Docs", "D")], optionShortcutsEnabled: true, quickNoteKey: "N")
        #expect(
            registrations.suffix(2) == [
                GlobalHotKeyRegistration(character: "D", action: .launchSite(index: 0)),
                GlobalHotKeyRegistration(character: "N", action: .openQuickNote),
            ])
        #expect(
            globalHotKeyRegistrations(for: [], optionShortcutsEnabled: false, quickNoteKey: "N")
                .isEmpty)
    }
}
