import SwiftUI

/// 노치 패널 한 칸의 렌더링 내용.
enum NotchSlotContent {
    /// 런처 목록 위젯.
    case launchers(LauncherListSection)
    /// 스크린샷 선반 위젯. 파일 목록은 뷰가 background queue에서 읽는다.
    case screenshots
    /// 다운로드 선반 위젯.
    case downloads
    /// Focus(Keep Mac Awake) 위젯.
    case awake
    /// 할 일 목록 위젯.
    case todo
    /// 실제 앱 창 배치를 복원하는 Workspaces 위젯.
    case workspaces([ChapWorkspace])
    /// 타이머 위젯.
    case timer

    /// 어깨로 접을 수 있는 칸이면 그 위젯. 런처·Focus 칸은 nil.
    var collapsibleWidget: NotchWidget? {
        switch self {
        case .screenshots: return .screenshots
        case .downloads: return .downloads
        case .launchers, .awake, .todo, .workspaces, .timer: return nil
        }
    }

    /// config의 위젯 배치를 실제로 그릴 칸으로 바꾼다. 빈 칸과 항목이 없는 런처 칸은 뺀다.
    /// 노치 패널과 오프스크린 렌더 도구가 같은 규칙을 쓴다.
    static func slots(
        widgets: [NotchWidget], sites: [Site], workspaces: [ChapWorkspace] = []
    ) -> [NotchSlotContent] {
        // 위젯 배치는 사용자가 명시적으로 고른 것이므로 메뉴의 숨김 설정과 무관하다.
        let sections = LauncherListPolicy.sections(sites: sites, hiddenLaunchTypes: [])
        return widgets.compactMap { widget -> NotchSlotContent? in
            switch widget {
            case .none, .drop:
                // Drop 파일은 메인 도커 하단 행이 전담한다.
                return nil
            case .screenshots: return .screenshots
            case .downloads: return .downloads
            case .awake: return .awake
            case .todo: return .todo
            case .workspaces: return .workspaces(workspaces)
            case .timer: return .timer
            case .sites, .apps, .folders:
                return sections.first { $0.launchType == widget.launchType }
                    .map(NotchSlotContent.launchers)
            }
        }
    }
}

/// 패널 펼침/접힘 상태와 실시간 조절 값. 컨트롤러가 접힘 애니메이션과
/// 불투명도 프리뷰를 구동할 수 있도록 뷰 외부에서 관찰 가능한 모델로 둔다.
final class NotchRevealModel: ObservableObject {
    @Published var revealed = false
    @Published var bottomOpacity: Double = Config.notchPanelOpacityDefault
    @Published var colorHex: String = Config.notchPanelColorHexDefault
    /// 파일 드래그가 노치에 닿아 "Drop here" 레이어를 덮어야 하는 상태.
    @Published var isDropTargetActive = false
    /// ⌥를 누르고 있는 동안. 키캡이 강조되고 "⌥1"처럼 수식키를 함께 보여준다.
    @Published var isOptionHeld = false
    /// 어깨 아이콘으로 접힌 위젯. 도커를 열 때 config에서 채우고, 접고 펼 때마다 저장한다.
    @Published var collapsedWidgets: [NotchWidget] = []
}

/// 도커 콘텐츠 크기를 창 컨트롤러로 올려 보내는 preference.
struct NotchContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
