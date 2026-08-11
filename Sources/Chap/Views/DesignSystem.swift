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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.bodyFont)
                .padding(DS.paddingSmall)
                .background(DS.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DS.border, lineWidth: 1)
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
