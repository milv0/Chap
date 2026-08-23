import SwiftUI

struct QAView: View {
    @State private var isEnglish = false

    private var sections: [(String, [(String, String)])] {
        isEnglish ? englishSections : koreanSections
    }

    // MARK: - Korean

    private let koreanSections: [(String, [(String, String)])] = [
        (
            "설치 & 권한",
            [
                (
                    "앱을 처음 실행했는데 단축키가 안 먹어요.",
                    "단축키에는 접근성 권한이 필요하지 않습니다. Chap을 재시작한 뒤에도 안 되면 다른 앱이 같은 Option 조합을 사용 중인지 확인해주세요."
                ),
                (
                    "접근성 권한을 허용했는데 리사이즈가 안 돼요.",
                    "Chap은 앱 시작, 메뉴 열기, Settings 열기, URL/App 실행 전에 권한을 다시 확인합니다. 권한 안내 직후에는 30초 동안 자동으로 허용 여부를 감지합니다."
                ),
                (
                    "Chrome이 없으면 사용 못 하나요?",
                    "URL 타입만 Chrome이 필요합니다. App, Finder, Shell 타입은 Chrome 없이도 사용 가능합니다."
                ),
                (
                    "Chrome 또는 Finder 권한 요청이 뜨는 이유는?",
                    "URL 창 재사용은 Chap이 만든 Chrome 창 ID를 확인하고 제어하며, Finder 타입은 폴더 창을 열기 위해 자동화를 사용합니다. 각 기능을 처음 사용할 때 macOS가 해당 앱 제어 권한을 요청할 수 있습니다."
                ),
                (
                    "macOS 버전 요구사항이 뭔가요?",
                    "macOS 14.0 (Sonoma) 이상이 필요합니다."
                ),
            ]
        ),
        (
            "단축키",
            [
                (
                    "단축키는 어떻게 설정하나요?",
                    "Settings에서 각 사이트의 \"Shortcut (⌥ +)\" 필드에 원하는 키 하나를 입력하면 됩니다. 예: T 입력 → ⌥T로 실행."
                ),
                (
                    "단축키를 안 넣어도 되나요?",
                    "네. 단축키 없이도 메뉴바 아이콘 클릭으로 실행할 수 있습니다."
                ),
                (
                    "같은 단축키를 두 개 사이트에 설정하면?",
                    "중복 경고가 뜨고 저장되지 않습니다. 다른 키를 사용해주세요."
                ),
                (
                    "⌥., ⌥, 는 바꿀 수 있나요?",
                    "아니요. ⌥.(메뉴 열기)와 ⌥,(설정 열기)는 시스템 단축키로 고정입니다."
                ),
            ]
        ),
        (
            "사이트 설정",
            [
                (
                    "URL을 열면 주소창이 없는 이유는?",
                    "Chrome의 --app 모드로 실행되기 때문입니다. 웹앱처럼 깔끔하게 사용할 수 있습니다."
                ),
                (
                    "\"Reuse Existing URL Window\"는 어떻게 동작하나요?",
                    "활성화 후 해당 항목을 처음 실행하면 Chap이 새 Chrome --app 창을 열고 그 창 ID를 항목별로 기억합니다. 다음 실행부터는 Chap이 직접 만든 그 창만 앞으로 가져와 설정한 크기와 위치를 다시 적용합니다."
                ),
                (
                    "이미 열어둔 일반 Chrome 탭도 재사용하나요?",
                    "아니요. URL, 창 제목, 현재 활성 창으로 사용자 탭을 검색하지 않습니다. 다른 Chrome 작업 창이 이동하지 않도록 Chap이 해당 항목으로 직접 만든 창만 재사용합니다."
                ),
                (
                    "재사용 창 연결은 언제 초기화되나요?",
                    "창을 닫거나 Chrome을 재시작하거나 URL을 변경하거나 재사용 옵션을 끄면 초기화됩니다. 연결 정보는 현재 Chap 실행 중에만 유지되므로 Chap을 재시작한 뒤 첫 실행에서는 새 창을 만들고 다시 연결합니다."
                ),
                (
                    "윈도우가 항상 화면 가운데 열려요. 위치를 바꿀 수 있나요?",
                    "현재는 선택한 디스플레이의 중앙에 자동 배치됩니다. 위치 커스텀은 지원하지 않습니다."
                ),
                (
                    "특정 모니터에서 열리게 하려면?",
                    "설정의 Display 목록에서 원하는 모니터를 선택하거나 All Displays에서 화면을 클릭하세요. Follow Cursor는 마우스 커서가 있는 화면에 열립니다."
                ),
                (
                    "같은 URL/앱을 두 번 등록하면?",
                    "중복 경고가 뜨고 저장되지 않습니다."
                ),
                (
                    "Shell 타입은 뭔가요?",
                    "터미널 명령어나 스크립트를 실행합니다. 윈도우 리사이즈 없이 명령만 실행됩니다."
                ),
            ]
        ),
        (
            "설정 & 저장",
            [
                (
                    "수정한 내용은 어떻게 저장하나요?",
                    "필드 클릭 → 수정 → Enter 또는 다른 사이트로 이동하면 자동 저장됩니다. ⌘S로도 저장 가능합니다."
                ),
                (
                    "사이트를 빠르게 추가하려면?",
                    "⌘N을 누르면 새 사이트가 추가되고 Name 필드에 자동 포커스됩니다."
                ),
                (
                    "설정 파일은 어디에 있나요?",
                    "~/.chap.json에 저장됩니다. 수동 편집도 가능하며, 앱 재시작 시 반영됩니다."
                ),
                (
                    "설정을 날렸어요. 복구할 수 있나요?",
                    "~/.chap.json.bak에 자동 백업이 있습니다. 이 파일을 ~/.chap.json으로 복사하면 복구됩니다."
                ),
                (
                    "다른 컴퓨터로 설정을 옮기려면?",
                    "Settings → Export로 JSON 파일을 저장하고, 다른 컴퓨터에서 Import하면 됩니다. JSON 파일을 설정 창에 드래그앤드랍해도 됩니다."
                ),
            ]
        ),
        (
            "디스플레이 & 리사이즈",
            [
                (
                    "멀티 모니터에서 어떤 화면에 열리나요?",
                    "사이트별로 디스플레이를 지정할 수 있습니다. Follow Cursor를 선택하면 마우스 커서가 있는 화면에 열리고, 다시 누르면 현재 프리뷰 또는 커서 화면으로 고정됩니다."
                ),
                (
                    "Size Preset은 어떻게 동작하나요?",
                    "Compact, Focus, Standard, Comfortable, Wide, Tall, Workspace, Max 중 하나를 고르면 실행할 때 화면 크기에 맞춰 다시 계산됩니다. Width나 Height를 직접 수정하면 Custom으로 바뀌고 그 값이 저장됩니다."
                ),
                (
                    "Follow Cursor에서 외장 모니터를 쓰면 프리셋 크기 기준은 뭔가요?",
                    "Follow Cursor는 창을 커서가 있는 화면에 띄우지만, 기본 프리셋 크기는 내장 디스플레이 기준으로 계산한 뒤 대상 화면에 맞게 줄입니다. Follow Cursor 중 All Displays에서 모니터를 클릭하면 커서 추적은 유지한 채 그 화면의 Size Preset 또는 Custom 크기를 따로 편집·저장할 수 있습니다. 일반 모드에서 All Displays를 클릭하면 해당 화면이 사이트의 target display로 선택됩니다. 프리뷰 창 중앙에는 현재 preset 또는 Custom label이 표시됩니다."
                ),
                (
                    "새 항목을 추가하면 어떤 프리셋이 기본인가요?",
                    "URL과 Shell은 Standard, App은 Comfortable, Finder는 Compact로 시작합니다. 이후 사용자가 바꿔 저장한 프리셋은 앱을 재시작해도 그대로 유지됩니다."
                ),
                (
                    "Guide Window가 뭔가요?",
                    "사이트 실행 시 윈도우가 열릴 위치를 반투명 테두리로 미리 보여주는 기능입니다. Settings 하단의 \"Guide Window\" 토글로 켜고 끌 수 있습니다."
                ),
                (
                    "윈도우 크기가 모니터보다 크면 어떻게 되나요?",
                    "자동으로 모니터 크기에 맞게 축소됩니다."
                ),
            ]
        ),
        (
            "기타",
            [
                (
                    "Dock에 아이콘이 안 보여요.",
                    "정상입니다. Chap은 메뉴바 전용 앱으로, Dock에 표시되지 않습니다."
                ),
                (
                    "앱을 완전히 삭제하려면?",
                    "Settings 하단의 📁 메뉴 → Uninstall을 선택하면 설정 파일과 함께 삭제됩니다."
                ),
                (
                    "앱이 갑자기 단축키에 반응을 안 해요.",
                    "Chap을 재시작해 단축키를 다시 등록하세요. 계속 안 되면 다른 앱이 같은 Option 조합을 먼저 등록했는지 확인해주세요."
                ),
            ]
        ),
    ]

    // MARK: - English

    private let englishSections: [(String, [(String, String)])] = [
        (
            "Installation & Permissions",
            [
                (
                    "Shortcuts don't work after first launch.",
                    "Shortcuts do not require Accessibility permission. Restart Chap, then check whether another app is using the same Option combination."
                ),
                (
                    "I granted Accessibility permission, but resizing still doesn't work.",
                    "Chap checks permission on launch, menu open, Settings open, and URL/app launch. After a permission prompt, it watches for approval for 30 seconds."
                ),
                (
                    "Do I need Chrome to use Chap?",
                    "Only the URL type requires Chrome. App, Finder, and Shell types work without Chrome."
                ),
                (
                    "Why does Chrome or Finder ask for permission?",
                    "URL window reuse uses automation to verify and control the Chrome window ID created by Chap, while the Finder type uses it to open folder windows. macOS may ask for permission the first time you use either feature."
                ),
                (
                    "What macOS version is required?",
                    "macOS 14.0 (Sonoma) or later is required."
                ),
            ]
        ),
        (
            "Shortcuts",
            [
                (
                    "How do I set up shortcuts?",
                    "In Settings, enter a single key in the \"Shortcut (⌥ +)\" field for each site. For example: enter T → press ⌥T to launch."
                ),
                (
                    "Is a shortcut required?",
                    "No. You can also launch sites by clicking the menubar icon."
                ),
                (
                    "What if I assign the same shortcut to two sites?",
                    "A duplicate warning appears and it won't be saved. Use a different key."
                ),
                (
                    "Can I change ⌥. and ⌥, shortcuts?",
                    "No. ⌥. (open menu) and ⌥, (open settings) are fixed system shortcuts."
                ),
            ]
        ),
        (
            "Site Configuration",
            [
                (
                    "Why is there no address bar when opening a URL?",
                    "It opens in Chrome's --app mode, which provides a clean web-app experience without browser UI."
                ),
                (
                    "How does \"Reuse Existing URL Window\" work?",
                    "On the first launch after enabling it, Chap opens a new Chrome --app window and remembers that window ID for this launchable. Later launches bring forward only that Chap-created window and reapply its configured size and position."
                ),
                (
                    "Does reuse select a regular Chrome tab I already opened?",
                    "No. Chap never searches user tabs by URL, window title, or the currently active window. It reuses only the window created by that launchable so another Chrome work window is not moved."
                ),
                (
                    "When is the reused-window link reset?",
                    "It resets when the window closes, Chrome restarts, the configured URL changes, or reuse is disabled. The link lasts only for the current Chap session, so the first launch after restarting Chap creates and links a new window."
                ),
                (
                    "Windows always open in the center. Can I change the position?",
                    "Currently, windows are always centered on the target display. Custom positioning is not supported."
                ),
                (
                    "How do I open on a specific monitor?",
                    "Choose the desired monitor from the Display list or click it in All Displays. Follow Cursor opens on the screen where your cursor is."
                ),
                (
                    "What if I register the same URL/app twice?",
                    "A duplicate warning appears and it won't be saved."
                ),
                (
                    "What is the Shell type?",
                    "It executes terminal commands or scripts. No window resizing is performed."
                ),
            ]
        ),
        (
            "Settings & Saving",
            [
                (
                    "How do I save changes?",
                    "Click a field → edit → press Enter or navigate to another site to auto-save. You can also use ⌘S."
                ),
                (
                    "How do I quickly add a site?",
                    "Press ⌘N to add a new site with automatic focus on the Name field."
                ),
                (
                    "Where is the config file stored?",
                    "At ~/.chap.json. You can edit it manually; changes take effect after restarting the app."
                ),
                (
                    "I lost my settings. Can I recover them?",
                    "An automatic backup exists at ~/.chap.json.bak. Copy it to ~/.chap.json to restore."
                ),
                (
                    "How do I transfer settings to another computer?",
                    "Use Settings → Export to save a JSON file, then Import it on the other computer. You can also drag & drop a .json file onto the settings window."
                ),
            ]
        ),
        (
            "Display & Resize",
            [
                (
                    "Which screen does it open on with multiple monitors?",
                    "You can assign a display per site. Choose Follow Cursor to open on the screen where your cursor is; press it again to pin the current preview or cursor screen."
                ),
                (
                    "How do Size Presets work?",
                    "Choose Compact, Focus, Standard, Comfortable, Wide, Tall, Workspace, or Max to recalculate the size for the screen at launch time. Editing Width or Height switches the item to Custom and saves that exact size."
                ),
                (
                    "What size reference does Follow Cursor use on external monitors?",
                    "Follow Cursor opens on the cursor screen, but default preset sizes are calculated from the built-in display first, then fitted to the target screen. While following the cursor, click a monitor in All Displays to edit and save that monitor's own Size Preset or Custom size without leaving Follow Cursor. In normal mode, clicking All Displays selects that screen as the site's target display. The preview window shows the current preset or Custom label in its center."
                ),
                (
                    "Which preset is used for new items?",
                    "URL and Shell start with Standard, App starts with Comfortable, and Finder starts with Compact. After you save a different preset, it stays with that item across app restarts."
                ),
                (
                    "What is the Guide Window?",
                    "It shows a translucent outline where the window will appear when launching a site. Toggle it with the \"Guide Window\" switch at the bottom of Settings."
                ),
                (
                    "What if the window is larger than the monitor?",
                    "It's automatically scaled down to fit within the monitor's visible area."
                ),
            ]
        ),
        (
            "Miscellaneous",
            [
                (
                    "I don't see a Dock icon.",
                    "That's normal. Chap is a menubar-only app and doesn't appear in the Dock."
                ),
                (
                    "How do I completely uninstall?",
                    "In Settings, click the 📁 menu → Uninstall. This removes the app along with its config files."
                ),
                (
                    "The app suddenly stopped responding to shortcuts.",
                    "Restart Chap to register its shortcuts again. If the issue continues, check whether another app registered the same Option combination first."
                ),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Language toggle header
            HStack {
                Spacer()
                Button(action: { isEnglish.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text(isEnglish ? "한국어" : "English")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(DS.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DS.accentSoft)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.padding)
            .padding(.top, DS.paddingSmall)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.spacing) {
                    ForEach(sections.indices, id: \.self) { sIdx in
                        let section = sections[sIdx]
                        CardSection {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.0)
                                    .font(DS.headlineFont)
                                    .foregroundColor(DS.textPrimary)
                                ForEach(section.1.indices, id: \.self) { qIdx in
                                    let qa = section.1[qIdx]
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Q. \(qa.0)")
                                            .font(DS.bodyFont.weight(.medium))
                                            .foregroundColor(DS.textPrimary)
                                        Text("A. \(qa.1)")
                                            .font(DS.bodyFont)
                                            .foregroundColor(DS.textSecondary)
                                    }
                                    if qIdx < section.1.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DS.padding)
                .textSelection(.enabled)
            }
        }
        .frame(minWidth: 1000, minHeight: 500)
        .background(DS.surfaceBg)
    }
}
