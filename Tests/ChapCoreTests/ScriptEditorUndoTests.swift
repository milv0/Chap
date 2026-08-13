import Cocoa
import Testing

@testable import Chap

@Suite("Script Editor Undo")
@MainActor
struct ScriptEditorUndoTests {
    @Test("editable script text accepts input and Control-Z undo/redo")
    func editableScriptTextUndoRedo() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        let textView = UndoableScriptTextView.makeEditable()
        window.contentView = textView
        window.makeFirstResponder(textView)

        #expect(textView.isEditable)
        #expect(textView.isSelectable)
        #expect(textView.textContainer != nil)

        textView.insertText("echo Chap", replacementRange: NSRange(location: 0, length: 0))
        #expect(textView.string == "echo Chap")

        textView.keyDown(with: keyEvent(modifiers: [.control]))
        #expect(textView.string.isEmpty)

        textView.keyDown(with: keyEvent(modifiers: [.control, .shift]))
        #expect(textView.string == "echo Chap")
    }

    private func keyEvent(modifiers: NSEvent.ModifierFlags) -> NSEvent {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "z",
                charactersIgnoringModifiers: "z",
                isARepeat: false,
                keyCode: 6)
        else {
            fatalError("Failed to create test key event.")
        }
        return event
    }
}
