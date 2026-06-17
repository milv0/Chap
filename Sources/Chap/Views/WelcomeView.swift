import SwiftUI

struct WelcomeView: View {
    var onOpenSettings: () -> Void
    @Environment(\.dismiss) var dismiss
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
                    description: "Register sites with name, URL, and window size"
                )
                OnboardingCard(
                    icon: "display",
                    title: "Choose Display",
                    description: "Pick a screen and size — always centered"
                )
                OnboardingCard(
                    icon: "keyboard",
                    title: "Quick Launch",
                    description: "⌥Q menu, ⌥1~9 launch, ⌥, settings"
                )
            }
            .padding(.horizontal, 24)

            Text(
                "First launch may not resize the window.\nRe-open the site and it will work."
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

            PrimaryButton(title: "Get Started") {
                if dontShowAgain {
                    UserDefaults.standard.set(true, forKey: "guideDisabled")
                }
                dismiss()
                onOpenSettings()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(width: 420, height: 480)
        .background(DS.surfaceBg)
    }
}
