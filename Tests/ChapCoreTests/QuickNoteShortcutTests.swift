import AppKit
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

    @Test("the key is registered whenever it is set and free; the notch does not matter")
    func registeredKey() {
        func key(_ shortcut: String?, sites: [Site] = []) -> String? {
            QuickNoteShortcutPolicy.registeredKey(shortcut: shortcut, sites: sites)
        }
        #expect(key("N") == "N")
        #expect(key(nil) == nil)
        #expect(key("") == nil)
        #expect(key(".") == nil)
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

@Suite("Quick Note window", .serialized)
@MainActor
struct QuickNoteWindowTests {
    /// Esc가 메모 창을 닫는지 본다. 창은 사용자의 실제 메모 파일을 읽기만 하므로(입력하지 않는다)
    /// 이 테스트는 메모를 바꾸지 않는다.
    @Test("Escape closes the note window")
    func escapeCloses() throws {
        QuickNoteWindow.show()
        let window = try #require(NSApp.windows.first { $0 is QuickNoteNSWindow })
        defer { if QuickNoteWindow.isOpen { window.close() } }
        #expect(QuickNoteWindow.isOpen)

        let escape = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: "\u{1B}",
                charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53))
        // 닫기 직전 남은 입력을 파일에 쓰라는 요청이 나가야 한다(Esc로 닫아도 저장된다).
        var didRequestFlush = false
        let observer = NotificationCenter.default.addObserver(
            forName: NotchQuickNoteView.flushRequest, object: nil, queue: nil
        ) { _ in didRequestFlush = true }
        defer { NotificationCenter.default.removeObserver(observer) }

        // 실제 앱에서는 local key monitor가 이 함수를 부른다. Esc는 삼켜서 TextEditor로 내려가지 않는다.
        #expect(QuickNoteWindow.handleKeyDown(escape) == nil)
        #expect(!QuickNoteWindow.isOpen)
        #expect(didRequestFlush)
    }

    @Test("other keys and other windows pass through")
    func otherKeysPassThrough() throws {
        QuickNoteWindow.show()
        let window = try #require(NSApp.windows.first { $0 is QuickNoteNSWindow })
        defer { if QuickNoteWindow.isOpen { window.close() } }

        func key(_ code: UInt16, windowNumber: Int) throws -> NSEvent {
            try #require(
                NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: windowNumber, context: nil, characters: "a",
                    charactersIgnoringModifiers: "a", isARepeat: false, keyCode: code))
        }
        // 다른 키는 그대로 편집기로 간다.
        let letter = try key(0, windowNumber: window.windowNumber)
        #expect(QuickNoteWindow.handleKeyDown(letter) === letter)
        // 다른 창의 Esc는 그 창이 처리한다.
        let elsewhere = try key(53, windowNumber: 0)
        #expect(QuickNoteWindow.handleKeyDown(elsewhere) === elsewhere)
        #expect(QuickNoteWindow.isOpen)
    }
}
