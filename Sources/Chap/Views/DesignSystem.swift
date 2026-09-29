import Cocoa
import SwiftUI

// MARK: - Design Tokens

enum DS {
    static let padding: CGFloat = 20
    static let paddingSmall: CGFloat = 12
    static let spacing: CGFloat = 16
    static let spacingSmall: CGFloat = 8
    static let radius: CGFloat = 12
    static let radiusSmall: CGFloat = 8

    static let accent = Color(red: 54 / 255, green: 100 / 255, blue: 255 / 255)
    static let accentSoft = accent.opacity(0.08)
    /// 밝은 대표 블루(#89A3FF, 웹 `--blue-light`). 검정 노치 띠 위 아이콘처럼 어두운 바탕에서
    /// 진한 액센트보다 부드럽게 읽힌다.
    static let accentLight = Color(red: 137 / 255, green: 163 / 255, blue: 255 / 255)

    /// 노치 아이콘 색. 대표 블루를 연하게 쓴다: 어두운 바탕은 밝은 블루, 밝은 바탕은 액센트 75%.
    /// 제목 글자는 중립 회색 그대로 두고 아이콘만 물들여, 파란색이 내용과 경쟁하지 않게 한다.
    static func notchIconColor(onDarkBackground: Bool) -> Color {
        onDarkBackground ? accentLight.opacity(0.9) : accent.opacity(0.75)
    }

    /// 검정 노치 띠 위 위젯 아이콘(Drop·Mirror·Quick Note) 색. 하드웨어 노치와 이어지는 띠라
    /// 흰색을 쓰고, 호버 시 한 단계 밝아진다. 켜진 도구만 액센트 블루로 바뀐다.
    static func notchStripIconColor(isHovered: Bool = false) -> Color {
        .white.opacity(isHovered ? 1 : 0.85)
    }
    /// 강조 입력면. 라이트/다크 모두에서 대비가 유지되도록 고정 RGB 대신 accent 틴트를 쓴다.
    static let accentSurface = accent.opacity(0.12)
    static let cardBg = Color(.controlBackgroundColor)
    static let surfaceBg = Color(.windowBackgroundColor)
    static let textPrimary = Color(.labelColor)
    static let textSecondary = Color(.secondaryLabelColor)
    static let textTertiary = Color(.tertiaryLabelColor)
    static let border = Color(.separatorColor)
    static let danger = Color(red: 235 / 255, green: 68 / 255, blue: 68 / 255)

    static let titleFont = Font.system(size: 22, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(size: 15, weight: .semibold)
    static let bodyFont = Font.system(size: 13)
    static let captionFont = Font.system(size: 11)

    // 노치 글자 체계: 세 단계만 쓴다 (HIG macOS Body 13 / Subheadline 11 / Footnote 10).
    /// 목록·메모 본문.
    static let notchBody = Font.system(size: 13)
    /// 섹션 제목·키캡.
    static let notchLabel = Font.system(size: 11, weight: .semibold)
    /// 저장 시각·아이콘 배지 같은 보조 정보. 노치의 최소 글자 크기.
    static let notchMeta = Font.system(size: 10, weight: .medium)
    /// 섹션 제목 줄 높이. 제목 옆 키캡 유무와 관계없이 모든 칸의 첫 줄이 맞는다.
    static let notchHeaderHeight: CGFloat = 16
    static let monoFont = Font.system(size: 12, design: .monospaced)
}

// MARK: - Reusable Layout Components

struct CardSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.padding)
            .background(DS.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }
}

struct InputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var alignment: HorizontalAlignment = .leading
    var textAlignment: TextAlignment = .leading
    var fieldBackground: Color = DS.surfaceBg
    var fieldBorder: Color = DS.border

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(label)
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.bodyFont)
                .multilineTextAlignment(textAlignment)
                .padding(DS.paddingSmall)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(fieldBorder, lineWidth: 1)
                )
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DS.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct ToolbarIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    var disabled: Bool = false
    @State private var isHovered = false

    var body: some View {
        // Button 대신 onTapGesture 사용 — 메뉴바(accessory) 앱에서 창이 비활성일 때
        // Button은 첫 클릭이 창 활성화에만 쓰여(acceptsFirstMouse=false) 더블클릭이
        // 필요해지는 반면, 탭 제스처는 첫 클릭에 바로 반응해 사이드바와 일관됨.
        Image(systemName: icon)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(disabled ? DS.textTertiary : color)
            .frame(width: 26, height: 26)
            .background(
                isHovered && !disabled
                    ? DS.border.opacity(0.4)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !disabled else { return }
                action()
            }
            .onHover { hovering in isHovered = hovering && !disabled }
    }
}

/// ToolbarIconButton과 동일한 시각 규격(12pt medium, 26×26, 호버 배경)의 드롭다운 메뉴.
/// borderlessButton 메뉴 스타일의 chevron 인디케이터와 자체 패딩을 없애
/// 툴바 아이콘들과 나란히 놓아도 정렬·크기가 일치한다.
struct ToolbarIconMenu<Content: View>: View {
    let icon: String
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.textSecondary)
                .frame(width: 26, height: 26)
                .background(isHovered ? DS.border.opacity(0.4) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering in isHovered = hovering }
    }
}
