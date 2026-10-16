import SwiftUI

struct NotchLauncherRow: View {
    let entry: LauncherListEntry
    let isOptionHeld: Bool
    let primaryForeground: Color
    let shortcutForeground: Color
    let textShadowOpacity: Double
    let hoverBackground: Color
    let keycapBackground: Color
    let action: () -> Void

    @State private var isHovered = false
    var body: some View {
        Button(action: action) {
            // 줄 앞 아이콘은 두지 않는다. 칸 제목 아이콘이 이미 종류를 알려 주고, 모든 줄이 같은 기호면
            // 정보 없이 반복만 된다. 아이콘은 줄마다 다른 정보를 줄 때만 쓴다(Downloads 파일 아이콘, Apps).
            HStack(spacing: 6) {
                Text(entry.site.name)
                    // 목록 본문은 Apple 기본 계층대로 regular. 섹션 헤더만
                    // semibold를 유지해 Glass에서 글자가 과하게 무거워지지 않는다.
                    // 모든 목록 줄은 같은 12pt(`notchRowName`)다.
                    .font(DS.notchRowName)
                    .foregroundColor(primaryForeground)
                    .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if let key = LauncherListPolicy.shortcutKey(for: entry.site) {
                    NotchKeycap(
                        key: key, isOptionHeld: isOptionHeld,
                        foreground: shortcutForeground, background: keycapBackground)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            // To-do·Downloads 줄과 같은 26pt. 글자 높이에 맡기면 25pt 안팎이라 4줄이 목록 칸 바닥에 못 닿는다.
            .frame(height: NotchAppIconTile.listRowHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(LauncherListPolicy.shortcutBadge(for: entry.site) ?? "")
        .accessibilityLabel(LauncherListPolicy.launchAccessibilityLabel(for: entry.site))
    }
}

/// 단축키 키캡. 평소에는 키 글자만(`1`, `N`) 보여 읽기 쉽게 하고, ⌥를 누르고 있으면
/// 액센트로 강조하며 `⌥1`로 바뀌어 어떤 조합인지 알려준다. 폭은 `⌥1` 기준으로 잡아
/// 바뀌어도 줄이 움직이지 않는다.
struct NotchKeycap: View {
    let key: String
    let isOptionHeld: Bool
    let foreground: Color
    let background: Color
    var font: Font = DS.notchMeta.weight(.semibold)
    /// 목록 줄은 `⌥1` 폭을 미리 잡아 줄이 움직이지 않게 한다. 아이콘 배지는 아이콘을
    /// 덜 가리도록 글자 폭만 쓴다 (겹쳐 그리는 배지라 폭이 바뀌어도 배치가 움직이지 않는다).
    var reservesModifierWidth = true

    var body: some View {
        ZStack {
            if reservesModifierWidth {
                Text("⌥\(key)").font(font).hidden()
            }
            Text(isOptionHeld ? "⌥\(key)" : key)
                .font(font)
                .foregroundColor(isOptionHeld ? .white : foreground)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isOptionHeld ? DS.accent : background)
        )
        .animation(.easeOut(duration: 0.12), value: isOptionHeld)
        .accessibilityHidden(true)
    }
}

/// Apps 칸의 아이콘 한 개. 호버 시 앱 이름 툴팁과 옅은 배경을 보여준다.
struct NotchAppIconTile: View {
    let entry: LauncherListEntry
    let isOptionHeld: Bool
    let primaryForeground: Color
    let badgeForeground: Color
    let badgeBackground: Color
    let hoverBackground: Color
    let action: () -> Void

    @State private var icon: NSImage?
    @State private var isHovered = false

    init(
        entry: LauncherListEntry, isOptionHeld: Bool, primaryForeground: Color,
        badgeForeground: Color, badgeBackground: Color, hoverBackground: Color,
        action: @escaping () -> Void
    ) {
        self.entry = entry
        self.isOptionHeld = isOptionHeld
        self.primaryForeground = primaryForeground
        self.badgeForeground = badgeForeground
        self.badgeBackground = badgeBackground
        self.hoverBackground = hoverBackground
        self.action = action
        // 캐시에 있으면 첫 프레임부터 아이콘을 그린다 (재오픈·오프스크린 렌더).
        _icon = State(initialValue: entry.site.appPath.flatMap(AppIconLoader.cachedIcon))
    }

    // 격자 3줄(앱 6개)의 높이를 목록 칸 4줄(Sites·Finder 최대)과 정확히 맞춘다.
    // 목록 한 줄 = 13pt 본문 줄 높이 16pt + 위아래 여백 5pt씩, 줄 간격 3pt.
    static let listRowHeight: CGFloat = 26
    static let listRowSpacing: CGFloat = 3
    static let listBodyHeight: CGFloat = 4 * listRowHeight + 3 * listRowSpacing  // 113pt
    /// 탭 칸(Launchers·Apps) 제목 줄과 본문 사이에 더 두는 간격. To-do 칸(제목 줄 21pt + 간격 4pt)과
    /// 같은 자리에서 목록이 시작하고 끝나도록 6pt를 둔다(16 + 3 + 6 = 21 + 4). 줄 높이·간격도 To-do와 같다.
    static let tabBodyTopGap: CGFloat = 6

    static let iconSize: CGFloat = 32
    /// 타일 한 변: 아이콘 + 호버 배경 여백 2pt씩.
    static let tileSize: CGFloat = iconSize + 2
    /// 가로 간격: 앱 아이콘의 투명 가장자리를 감안해 넉넉히 둔다.
    static let columnGap: CGFloat = 8
    /// 세로 간격. 3열 × 2줄이라 목록 4줄 높이(113pt) 안에 여유가 있다. 키캡 배지가 아래 줄과 붙지 않게 둔다.
    static let rowGap: CGFloat = 12

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .foregroundColor(primaryForeground.opacity(0.5))
                            .padding(6)
                    }
                }
                .frame(width: Self.iconSize, height: Self.iconSize)
                .frame(width: Self.tileSize, height: Self.tileSize)

                if let key = LauncherListPolicy.shortcutKey(for: entry.site) {
                    // 목록과 같은 키캡. 아이콘 위에서도 읽히도록 반투명 재질을 깐다.
                    NotchKeycap(
                        key: key, isOptionHeld: isOptionHeld,
                        foreground: badgeForeground, background: badgeBackground,
                        font: DS.notchMeta.weight(.semibold),
                        reservesModifierWidth: false
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .offset(x: 3, y: 3)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(
            LauncherListPolicy.shortcutBadge(for: entry.site).map { "\(entry.site.name)  \($0)" }
                ?? entry.site.name
        )
        .accessibilityLabel(LauncherListPolicy.launchAccessibilityLabel(for: entry.site))
        .task(id: entry.site.appPath) {
            guard let path = entry.site.appPath, !path.isEmpty else { return }
            icon = AppIconLoader.cachedIcon(forAppPath: path)
            if icon == nil { icon = await AppIconLoader.icon(forAppPath: path) }
        }
    }
}

/// 런처 칸 제목. 호버 시 옅은 면과 › 표시, 누르면 설정창을 연다.
struct NotchSectionTitleButton: View {
    let symbol: String
    let title: String
    let foreground: Color
    let iconForeground: Color
    let hoverBackground: Color
    let textShadowOpacity: Double
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(DS.notchLabel)
                    .foregroundColor(iconForeground)
                Text(title)
                    .font(DS.notchLabel)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(isHovered ? 1 : 0)
            }
            .foregroundColor(foreground)
            .shadow(color: .black.opacity(textShadowOpacity), radius: 1.5, y: 0.5)
            .padding(.horizontal, 6)
            .frame(height: DS.notchHeaderHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusSmall, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Edit \(title) in Settings")
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title) in Chap Settings")
        .accessibilityAddTraits(.isHeader)
    }
}
