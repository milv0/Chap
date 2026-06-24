import SwiftUI

struct QAView: View {
    private let sections: [(String, [(String, String)])] = [
        ("설치 & 권한", [
            ("앱을 처음 실행했는데 단축키가 안 먹어요.",
             "접근성 권한이 필요합니다. System Settings → Privacy & Security → Accessibility에서 Chap을 허용해주세요. 메뉴바 아이콘에 경고 표시(⚠️)가 있다면 권한이 없는 상태입니다."),
            ("권한을 허용했는데도 안 돼요.",
             "권한 허용 후 앱을 한 번 재시작해야 합니다. 메뉴바 아이콘 → Restart를 눌러주세요."),
            ("Chrome이 없으면 사용 못 하나요?",
             "URL 타입만 Chrome이 필요합니다. App, Finder, Shell 타입은 Chrome 없이도 사용 가능합니다."),
            ("macOS 버전 요구사항이 뭔가요?",
             "macOS 14.0 (Sonoma) 이상이 필요합니다."),
        ]),
        ("단축키", [
            ("단축키는 어떻게 설정하나요?",
             "Settings에서 각 사이트의 \"Shortcut (⌥ +)\" 필드에 원하는 키 하나를 입력하면 됩니다. 예: T 입력 → ⌥T로 실행."),
            ("단축키를 안 넣어도 되나요?",
             "네. 단축키 없이도 메뉴바 아이콘 클릭으로 실행할 수 있습니다."),
            ("같은 단축키를 두 개 사이트에 설정하면?",
             "중복 경고가 뜨고 저장되지 않습니다. 다른 키를 사용해주세요."),
            ("⌥Q, ⌥, 는 바꿀 수 있나요?",
             "아니요. ⌥Q(메뉴 열기)와 ⌥,(설정 열기)는 시스템 단축키로 고정입니다."),
        ]),
        ("사이트 설정", [
            ("URL을 열면 주소창이 없는 이유는?",
             "Chrome의 --app 모드로 실행되기 때문입니다. 웹앱처럼 깔끔하게 사용할 수 있습니다."),
            ("윈도우가 항상 화면 가운데 열려요. 위치를 바꿀 수 있나요?",
             "현재는 선택한 디스플레이의 중앙에 자동 배치됩니다. 위치 커스텀은 지원하지 않습니다."),
            ("특정 모니터에서 열리게 하려면?",
             "설정의 Display Preview에서 원하는 모니터를 클릭하세요. 다시 클릭하면 Auto(커서 위치 기반)로 돌아갑니다. 또는 Display 드롭다운에서 선택할 수도 있습니다."),
            ("같은 URL/앱을 두 번 등록하면?",
             "중복 경고가 뜨고 저장되지 않습니다."),
            ("Shell 타입은 뭔가요?",
             "터미널 명령어나 스크립트를 실행합니다. 윈도우 리사이즈 없이 명령만 실행됩니다."),
        ]),
        ("설정 & 저장", [
            ("수정한 내용은 어떻게 저장하나요?",
             "필드 클릭 → 수정 → Enter 또는 다른 사이트로 이동하면 자동 저장됩니다. ⌘S로도 저장 가능합니다."),
            ("설정 파일은 어디에 있나요?",
             "~/.chap.json에 저장됩니다. 수동 편집도 가능하며, 앱 재시작 시 반영됩니다."),
            ("설정을 날렸어요. 복구할 수 있나요?",
             "~/.chap.json.bak에 자동 백업이 있습니다. 이 파일을 ~/.chap.json으로 복사하면 복구됩니다."),
            ("다른 컴퓨터로 설정을 옮기려면?",
             "Settings → Export로 JSON 파일을 저장하고, 다른 컴퓨터에서 Import하면 됩니다. JSON 파일을 설정 창에 드래그앤드랍해도 됩니다."),
        ]),
        ("디스플레이 & 리사이즈", [
            ("멀티 모니터에서 어떤 화면에 열리나요?",
             "사이트별로 디스플레이를 지정할 수 있습니다. 지정 안 하면(Auto) 마우스 커서가 있는 화면에 열립니다."),
            ("Guide Window가 뭔가요?",
             "사이트 실행 시 윈도우가 열릴 위치를 반투명 테두리로 미리 보여주는 기능입니다. Settings 하단의 \"Guide Window\" 토글로 켜고 끌 수 있습니다."),
            ("윈도우 크기가 모니터보다 크면 어떻게 되나요?",
             "자동으로 모니터 크기에 맞게 축소됩니다."),
        ]),
        ("기타", [
            ("Dock에 아이콘이 안 보여요.",
             "정상입니다. Chap은 메뉴바 전용 앱으로, Dock에 표시되지 않습니다."),
            ("앱을 완전히 삭제하려면?",
             "Settings 하단의 📁 메뉴 → Uninstall을 선택하면 설정 파일과 함께 삭제됩니다."),
            ("앱이 갑자기 단축키에 반응을 안 해요.",
             "접근성 권한이 제거되었을 수 있습니다. 메뉴바 아이콘에 경고 표시가 있는지 확인하고, System Settings에서 권한을 다시 허용해주세요."),
        ]),
    ]

    var body: some View {
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
        }
        .frame(minWidth: 1000, minHeight: 500)
        .background(DS.surfaceBg)
    }
}
