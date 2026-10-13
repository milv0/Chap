import SwiftUI

/// 노치 위젯이 공유하는 전경 색 묶음. 패널 스타일(Custom/Glass)에 맞춰 계산된 값을 받는다.
struct NotchWidgetPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    /// 섹션 제목·아이콘 색.
    let heading: Color
    let textShadowOpacity: Double
    let hoverBackground: Color
    let subtleSurface: Color
    /// 제목 아이콘 색 (연한 대표 블루). nil이면 제목 색을 쓴다.
    var icon: Color? = nil

    /// 제목 아이콘 색만 바꾼 사본 (Focus가 켜지면 진한 블루).
    func withIcon(_ color: Color) -> NotchWidgetPalette {
        var copy = self
        copy.icon = color
        return copy
    }
}

/// 위젯 칸 상단의 아이콘+제목 줄. 런처 섹션 제목과 같은 모양이다.
struct NotchWidgetHeader: View {
    let symbol: String
    let title: String
    let palette: NotchWidgetPalette

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(DS.notchLabel)
                .foregroundColor(palette.icon ?? palette.heading)
            Text(title)
                .font(DS.notchLabel)
                .foregroundColor(palette.heading)
        }
        .shadow(color: .black.opacity(palette.textShadowOpacity), radius: 1.5, y: 0.5)
        .padding(.horizontal, 6)
        .frame(height: DS.notchHeaderHeight)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 위젯 본문 높이. 목록 칸 4줄과 정확히 같아 모든 칸의 바닥선이 맞는다.
let widgetBodyHeight: CGFloat = NotchAppIconTile.listBodyHeight

/// 노치 선반(Screenshots·Downloads) 목록. 목록 칸 4줄 높이(113pt)에 고정하고, 더 있으면
/// 트랙패드·휠로 스크롤한다. 스크롤바는 시스템 설정("항상 보기")과 관계없이 숨기고,
/// 아래로 더 있을 때만 맨 아래를 살짝 흐리게 해 이어진다는 것을 알린다.
struct NotchShelfScrollList<Content: View>: View {
    let itemCount: Int
    let visibleRows: Int
    @ViewBuilder let content: () -> Content

    /// 맨 아래 흐림 높이. 끝까지 내리면 같은 만큼의 여백이 마지막 줄을 흐림 밖으로 올린다.
    private static var fadeHeight: CGFloat { 10 }

    private var scrolls: Bool { itemCount > visibleRows }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: NotchAppIconTile.listRowSpacing) {
                content()
            }
            .padding(.bottom, scrolls ? Self.fadeHeight : 0)
        }
        .scrollIndicators(.never)
        .scrollDisabled(!scrolls)
        .frame(height: NotchAppIconTile.listBodyHeight, alignment: .top)
        .mask {
            VStack(spacing: 0) {
                Color.black
                LinearGradient(
                    colors: [.black, scrolls ? .black.opacity(0) : .black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: Self.fadeHeight)
            }
        }
    }
}

/// 선반 제목에서 폴더 열기 요청. 앱이 일반 Finder 실행 경로(Standard 프리셋, 커서 화면
/// 가운데)로 연다. object는 폴더 URL, userInfo["name"]은 로그용 이름이다.
enum NotchShelfFolder {
    static let openRequest = Notification.Name("ChapShelfFolderOpen")

    static func open(_ url: URL, name: String) {
        NotificationCenter.default.post(name: openRequest, object: url, userInfo: ["name": name])
    }
}

/// 선반 제목 줄 오른쪽 끝의 접기 버튼. 칸에 마우스를 올렸을 때만 보인다.
/// 누르면 칸이 도커 어깨(검정 띠 옆 밝은 띠)의 아이콘으로 접힌다.
struct NotchCollapseButton: View {
    let isVisible: Bool
    let foreground: Color
    let hoverBackground: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.up")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(foreground)
                .frame(width: 18, height: DS.notchHeaderHeight)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                        .fill(isHovered ? hoverBackground : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(isVisible ? 1 : 0)
        .help("Collapse")
        .accessibilityLabel("Collapse")
    }
}

/// 검정 띠 왼쪽에 놓인 접힌 선반 아이콘. 띠 도구와 같은 흰색이며, 누르면 원래 자리에서 다시 펼쳐진다.
struct NotchStripShelfIcon: View {
    let symbol: String
    let title: String
    let height: CGFloat
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(DS.notchStripIconFont)
                .foregroundColor(DS.notchStripIconColor(isHovered: isHovered))
                .frame(width: NotchLauncherPolicy.stripToolPitch, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Show \(title)")
        .accessibilityLabel("Show \(title)")
    }
}
