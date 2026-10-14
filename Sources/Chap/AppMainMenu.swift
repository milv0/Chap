import Cocoa

/// 앱의 숨은 메인 메뉴. Chap은 메뉴 막대 앱이라 메뉴가 화면에 보이지 않지만, ⌘Z·⌘C 같은 편집 단축키는
/// 이 메뉴 항목을 통해서만 텍스트 칸(Quick Note·설정창 입력칸·To-do)에 전달된다. 항목이 없으면 그 키는
/// 아무 일도 하지 않는다. action은 first responder로 가므로 텍스트 칸이 커서를 가졌을 때만 동작한다.
enum AppMainMenu {
    static func make() -> NSMenu {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = makeEditMenu()
        mainMenu.addItem(editMenuItem)
        return mainMenu
    }

    static func makeEditMenu() -> NSMenu {
        let editMenu = NSMenu(title: "Edit")
        // NSTextView의 undo는 창의 undoManager가 맡는다. 여기 항목은 단축키를 그 manager로 보내기만 한다.
        editMenu.addItem(
            withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(
            withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(
            withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return editMenu
    }
}
