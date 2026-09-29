import SwiftUI

struct WelcomeView: View {
    var onOpenSettings: () -> Void
    var onOpenAccessibilitySettings: () -> Void
    var onClose: () -> Void
    @State private var dontShowAgain = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 정체성: 메뉴바 속 친구 (BRAND.md). 첫인사는 친구처럼 짧게.
            VStack(spacing: 6) {
                Text("Hi, I'm Chap.")
                    .font(DS.titleFont)
                    .foregroundColor(DS.textPrimary)
                Text(
                    "Your friend in the menu bar. Tell me what you open most, "
                        + "and I'll bring it to the center of your screen."
                )
                .font(DS.bodyFont)
                .foregroundColor(DS.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
            }

            VStack(spacing: 10) {
                OnboardingCard(
                    icon: "plus.circle.fill",
                    title: "Add Sites",
                    description: "Register sites, apps, and folders"
                )
                OnboardingCard(
                    icon: "keyboard",
                    title: "Set Shortcuts",
                    description: "Assign custom key per site (e.g. T → ⌥T to launch)"
                )
                OnboardingCard(
                    icon: "display",
                    title: "Choose Display",
                    description: "Pick Follow Cursor or a display, then choose a size preset"
                )
                OnboardingCard(
                    icon: "bolt.fill",
                    title: "Quick Launch",
                    description: "⌥. menu, ⌥(your key) launch, ⌥, settings"
                )
            }
            .padding(.horizontal, 24)

            Text(
                "URL sites open in Google Chrome (--app mode).\n"
                    + "First launch may not resize the window — re-open and it will work."
            )
            .font(DS.captionFont)
            .foregroundColor(DS.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Spacer()

            Toggle("Don't show this again", isOn: $dontShowAgain)
                .toggleStyle(.checkbox)
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)

            Button("Allow Accessibility") {
                onOpenAccessibilitySettings()
            }
            .buttonStyle(.plain)
            .font(DS.captionFont)
            .foregroundColor(DS.accent)

            PrimaryButton(title: "Get Started") {
                if dontShowAgain {
                    UserDefaults.standard.set(true, forKey: "guideDisabled")
                }
                onClose()
                onOpenSettings()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(width: 420, height: 480)
        .background(DS.surfaceBg)
    }
}
