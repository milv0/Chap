import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 편집 단축키(⌘Z·⇧⌘Z·⌘X·⌘C·⌘V·⌘A)를 텍스트 칸에 보내는 숨은 Edit 메뉴.
app.mainMenu = AppMainMenu.make()

app.run()
