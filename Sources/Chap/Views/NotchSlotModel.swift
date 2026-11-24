import SwiftUI

/// 노치 패널 한 칸의 렌더링 내용.
enum NotchSlotContent {
    /// Sites·Finder 목록을 탭으로 바꿔 보는 한 칸. 항목이 있는 타입만, launch type 순서로 담는다.
    case launcherTabs([LauncherListSection])
    /// Apps(아이콘 격자)·Layouts(타일)를 탭으로 바꿔 보는 한 칸. 앱이 없으면 Layouts만.
    case apps(LauncherListSection?, [ChapLayout])
    /// 스크린샷 선반 위젯. 파일 목록은 뷰가 background queue에서 읽는다.
    case screenshots
    /// 다운로드 선반 위젯.
    case downloads
    /// Keep Awake 위젯: 다이얼 하나로 Keep Awake와 타이머를 켠다.
    case awake
    /// 할 일 목록 위젯.
    case todo

    /// 어깨로 접을 수 있는 칸이면 그 위젯. 런처·Keep Awake 칸은 nil.
    var collapsibleWidget: NotchWidget? {
        switch self {
        case .screenshots: return .screenshots
        case .downloads: return .downloads
        case .launcherTabs, .apps, .awake, .todo: return nil
        }
    }

    /// config의 위젯 배치를 실제로 그릴 칸으로 바꾼다. 빈 칸과 항목이 없는 런처 칸은 뺀다.
    /// 노치 패널과 오프스크린 렌더 도구가 같은 규칙을 쓴다.
    static func slots(
        widgets: [NotchWidget], sites: [Site], layouts: [ChapLayout] = []
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
            case .apps:
                return .apps(sections.first { $0.launchType == .app }, layouts)
            case .launchers:
                let lists = sections.filter {
                    LauncherListPolicy.launcherTabTypes.contains($0.launchType)
                }
                return lists.isEmpty ? nil : .launcherTabs(lists)
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
    /// 파일을 끌어올 때 도커 테두리 빛의 색. nil이면 노치 빛이 꺼져 있다.
    @Published var glowPalette: NotchGlowPalette?
    /// 파일 드래그가 노치에 닿아 "Drop here" 레이어를 덮어야 하는 상태.
    @Published var isDropTargetActive = false
    /// ⌥를 누르고 있는 동안. 키캡이 강조되고 "⌥1"처럼 수식키를 함께 보여준다.
    @Published var isOptionHeld = false
    /// 어깨 아이콘으로 접힌 위젯. 도커를 열 때 config에서 채우고, 접고 펼 때마다 저장한다.
    @Published var collapsedWidgets: [NotchWidget] = []
    /// 지금 검정 띠 테두리를 두르는 노치 빛(한 번 빛나는 순간). nil이면 없다.
    @Published private(set) var stripGlow: StripGlow?
    /// 띠 빛이 보이는지. 나타나고 사라질 때 이 값을 애니메이션으로 바꾼다.
    @Published private(set) var isStripGlowVisible = false

    struct StripGlow: Equatable {
        let id: Int
        let palette: NotchGlowPalette
        let lineWidth: CGFloat
    }

    private var stripGlowToken = 0

    /// 검정 띠 테두리를 한 번 빛낸다: 접힌 노치의 빛(`NotchBeamFlash.show`)과 같은 길이·굵기·나타나고 사라지는 시간.
    /// 빛나는 중에 다시 부르면 새 순간으로 바꾼다.
    func flashStripGlow(palette: NotchGlowPalette, moment: NotchGlowMoment) {
        stripGlowToken += 1
        let current = stripGlowToken
        stripGlow = StripGlow(id: current, palette: palette, lineWidth: CGFloat(moment.lineWidth))
        isStripGlowVisible = false
        let fadeIn = min(0.25, moment.duration * 0.2)
        let fadeOut = min(0.6, moment.duration * 0.4)
        DispatchQueue.main.async {
            guard current == self.stripGlowToken else { return }
            withAnimation(.easeOut(duration: fadeIn)) { self.isStripGlowVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + moment.duration - fadeOut) {
            guard current == self.stripGlowToken else { return }
            withAnimation(.easeIn(duration: fadeOut)) { self.isStripGlowVisible = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + moment.duration + 0.05) {
            guard current == self.stripGlowToken else { return }
            // 다 사라진 빛은 떼어, 애니메이션을 계속 돌리지 않게 한다.
            self.stripGlow = nil
        }
    }
}

/// 도커 콘텐츠 크기를 창 컨트롤러로 올려 보내는 preference.
struct NotchContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
