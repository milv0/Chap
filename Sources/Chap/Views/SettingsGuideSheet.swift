import SwiftUI

/// Guide sheet presented from SettingsView (⌘/ or "?" button).
/// Extracted from SettingsView to isolate the guide-sheet responsibility.
struct SettingsGuideSheet: View {
    @Binding var isGuideEnglish: Bool
    let onClose: () -> Void
    let onOpenQA: () -> Void

    var body: some View {
        VStack(spacing: DS.spacing) {
            HStack {
                Text(isGuideEnglish ? "User Guide" : "사용자 가이드")
                    .font(DS.titleFont)
                    .foregroundColor(DS.textPrimary)

                Spacer()

                Picker("", selection: $isGuideEnglish) {
                    Text("한국어").tag(false)
                    Text("English").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 10) {
                CardSection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isGuideEnglish ? "Launch" : "실행")
                            .font(DS.headlineFont)
                            .foregroundColor(DS.textPrimary)
                        guideRow(
                            icon: "cursorarrow.click.2",
                            text: isGuideEnglish
                                ? "Use the menubar icon to launch items"
                                : "메뉴바 아이콘에서 항목을 실행")
                        guideRow(
                            icon: "keyboard",
                            text: isGuideEnglish
                                ? "⌥. menu, ⌥ custom key launch, ⌥, settings"
                                : "⌥. 메뉴, ⌥ 커스텀키 실행, ⌥, 설정")
                        guideRow(
                            icon: "checkmark.shield",
                            text: isGuideEnglish
                                ? "Allow Accessibility for URL/app resizing"
                                : "URL/App 리사이즈를 위해 접근성 권한 허용")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                CardSection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isGuideEnglish ? "Settings" : "설정")
                            .font(DS.headlineFont)
                            .foregroundColor(DS.textPrimary)
                        guideRow(
                            icon: "plus.circle",
                            text: isGuideEnglish
                                ? "Add URL, App, Finder, or Shell items"
                                : "URL, App, Finder, Shell 항목 추가")
                        guideRow(
                            icon: "display",
                            text: isGuideEnglish
                                ? "Choose a display and size preset per item"
                                : "항목별 디스플레이와 크기 프리셋 선택")
                        guideRow(
                            icon: "square.and.arrow.down",
                            text: isGuideEnglish
                                ? "Import/export JSON from the ··· menu"
                                : "··· 메뉴에서 JSON 가져오기/내보내기")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onOpenQA) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                        Text(isGuideEnglish ? "Open Full Q&A" : "전체 Q&A 열기")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DS.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DS.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                PrimaryButton(title: isGuideEnglish ? "Close" : "닫기") { onClose() }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .frame(width: 460, height: 540)
        .background(DS.surfaceBg)
    }

    // MARK: - Helpers

    private func guideRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(DS.accent)
                .frame(width: 16)
            Text(text)
                .font(DS.bodyFont)
                .foregroundColor(DS.textSecondary)
        }
    }
}
