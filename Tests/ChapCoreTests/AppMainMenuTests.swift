import AppKit
import Testing

@testable import Chap

@Suite("App main menu")
@MainActor
struct AppMainMenuTests {
    private func item(_ title: String) -> NSMenuItem? {
        AppMainMenu.makeEditMenu().items.first { $0.title == title }
    }

    @Test("Undo and Redo reach text fields through ⌘Z and ⇧⌘Z")
    func undoRedoShortcuts() throws {
        let undo = try #require(item("Undo"))
        #expect(undo.action == Selector(("undo:")))
        #expect(undo.keyEquivalent == "z")
        #expect(undo.keyEquivalentModifierMask == .command)

        let redo = try #require(item("Redo"))
        #expect(redo.action == Selector(("redo:")))
        #expect(redo.keyEquivalent == "z")
        #expect(redo.keyEquivalentModifierMask == [.command, .shift])
    }

    @Test("cut, copy, paste, and select all keep their shortcuts")
    func clipboardShortcuts() {
        let expected: [(String, Selector, String)] = [
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a"),
        ]
        for (title, action, key) in expected {
            #expect(item(title)?.action == action, "\(title)")
            #expect(item(title)?.keyEquivalent == key, "\(title)")
        }
    }

    @Test("a text view undoes typing when ⌘Z goes through the edit menu")
    func textViewUndoesThroughMenu() throws {
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 200, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        textView.allowsUndo = true
        window.contentView = textView
        window.makeFirstResponder(textView)
        textView.insertText("hello", replacementRange: NSRange(location: 0, length: 0))
        // 입력 묶음을 끊어 undo 한 번이 방금 입력을 되돌리게 한다.
        textView.breakUndoCoalescing()
        #expect(textView.string == "hello")

        // 메뉴의 Undo 항목이 보내는 action을 first responder(텍스트 뷰)부터 응답 사슬로 보낸다.
        // ⌘Z가 하는 일과 같다. undo:는 텍스트 뷰가 아니라 창이 undoManager로 처리한다.
        let undo = try #require(item("Undo")?.action)
        #expect(textView.tryToPerform(undo, with: nil))

        #expect(textView.string.isEmpty)
    }
}
