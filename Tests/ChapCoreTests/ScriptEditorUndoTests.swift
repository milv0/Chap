import Cocoa
import Testing

@testable import Chap

@Suite("Script Editor Undo")
@MainActor
struct ScriptEditorUndoTests {
    @Test("Control-Z undoes and Control-Shift-Z redoes")
    func controlZUndoRedo() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        let textView = UndoableScriptTextView(frame: .zero)
        window.contentView = textView
        window.makeFirstResponder(textView)

        guard let undoManager = textView.undoManager else {
            Issue.record("Script editor must have an undo manager when attached to a window.")
            return
        }

        let target = UndoRedoTarget(undoManager: undoManager)
        undoManager.registerUndo(withTarget: target) { target in
            target.undoChange()
        }

        textView.keyDown(with: keyEvent(modifiers: [.control]))
        #expect(target.value == "before")

        textView.keyDown(with: keyEvent(modifiers: [.control, .shift]))
        #expect(target.value == "after")
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

@MainActor
private final class UndoRedoTarget {
    private let undoManager: UndoManager
    var value = "after"

    init(undoManager: UndoManager) {
        self.undoManager = undoManager
    }

    func undoChange() {
        value = "before"
        undoManager.registerUndo(withTarget: self) { target in
            target.redoChange()
        }
    }

    func redoChange() {
        value = "after"
        undoManager.registerUndo(withTarget: self) { target in
            target.undoChange()
        }
    }
}
