import Cocoa
import SwiftUI

// MARK: - General Tab

/// Settings > General 탭. Behavior/Appearance/Updates 설정과 앱 버전 표시를 담당한다.
struct GeneralSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @ObservedObject var updateController: UpdateController
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Form {
                    Section("Behavior") {
                        Toggle("Guide Window", isOn: $vm.showGuideWindow)
                            .onChange(of: vm.showGuideWindow) { _, _ in onSave() }

                        Toggle("Open at Login", isOn: $vm.launchAtLogin)
                            .onChange(of: vm.launchAtLogin) { _, _ in onSave() }

                        Toggle(
                            "Enable Chap Option-Key Triggers",
                            isOn: $vm.optionShortcutsEnabled
                        )
                        .help(
                            "Disable when another workflow needs Chap's Option-key combinations."
                        )
                        .onChange(of: vm.optionShortcutsEnabled) { _, _ in onSave() }

                        Label(
                            "Turn this off temporarily when another app or workflow needs "
                                + "Option-key combinations.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundColor(DS.textSecondary)
                    }

                    Section("Appearance") {
                        HStack(alignment: .center) {
                            Text("Status Bar Icon")
                            Spacer()
                            HStack(spacing: 8) {
                                ForEach(
                                    StatusBarIconChoice.allCases,
                                    id: \.self
                                ) { choice in
                                    StatusBarIconChoiceButton(
                                        choice: choice,
                                        isSelected: vm.statusBarIcon == choice,
                                        action: { vm.statusBarIcon = choice })
                                }
                            }
                        }
                        .onChange(of: vm.statusBarIcon) { _, _ in onSave() }
                    }

                    Section("Updates") {
                        Toggle(
                            "Check for Updates Automatically",
                            isOn: Binding(
                                get: {
                                    updateController.automaticallyChecksForUpdates
                                },
                                set: {
                                    updateController.setAutomaticallyChecksForUpdates($0)
                                }
                            )
                        )
                        .disabled(!updateController.canCheckForUpdates)
                        .help("Check once per day and notify when an update is available.")
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                Text("Chap \(Defaults.appVersion)")
                    .font(.callout)
                    .foregroundColor(DS.textSecondary)
            }
            .padding(.bottom, 12)
        }
        .background(DS.surfaceBg)
    }
}

// MARK: - Status Bar Icon Controls

private struct StatusBarIconPreview: View {
    let choice: StatusBarIconChoice
    let color: Color

    var body: some View {
        Group {
            switch choice {
            case .default:
                if let image = NSImage(named: "StatusBarIcon") {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                }
            case .lightning:
                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundColor(color)
        .frame(width: 20, height: 20)
    }
}

private struct StatusBarIconChoiceButton: View {
    let choice: StatusBarIconChoice
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var title: String {
        switch choice {
        case .default: return "Default icon"
        case .lightning: return "Lightning icon"
        }
    }

    private var backgroundColor: Color {
        if isSelected { return DS.accentSoft }
        if isHovered { return DS.border.opacity(0.25) }
        return .clear
    }

    private var borderColor: Color {
        isSelected ? DS.accent : DS.border
    }

    var body: some View {
        Button(action: action) {
            StatusBarIconPreview(
                choice: choice,
                color: isSelected ? DS.accent : DS.textSecondary
            )
            .frame(width: 64, height: 34)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovered = $0 }
    }
}
