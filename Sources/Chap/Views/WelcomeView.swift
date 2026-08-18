import SwiftUI

struct WelcomeView: View {
    var onOpenSettings: () -> Void
    var onOpenAccessibilitySettings: () -> Void
    var onClose: () -> Void
    @State private var dontShowAgain = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Welcome to Chap")
                .font(DS.titleFont)
                .foregroundColor(DS.textPrimary)

            VStack(spacing: 10) {
                OnboardingCard(
                    icon: "plus.circle.fill",
                    title: "Add Sites",
                    description: "Register sites, apps, folders, and scripts"
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
