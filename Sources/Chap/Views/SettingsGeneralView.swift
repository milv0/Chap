import Cocoa
import SwiftUI

// MARK: - General Tab

/// Settings > General 탭. Behavior/Appearance/Menu/Updates 설정과 앱 버전 표시를 담당한다.
struct GeneralSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @ObservedObject var updateController: UpdateController
    let onSave: () -> Void

    /// 메뉴 섹션 표시 여부를 반전한다. 끄면 hiddenMenuLaunchTypes에 추가된다.
    private func toggleMenuSection(_ type: LaunchType) {
        if vm.hiddenMenuLaunchTypes.contains(type) {
            vm.hiddenMenuLaunchTypes.remove(type)
        } else {
            vm.hiddenMenuLaunchTypes.insert(type)
        }
        onSave()
    }

    private static func menuSectionName(_ type: LaunchType) -> String {
        switch type {
        case .url: return "URL"
        case .app: return "App"
        case .finder: return "Finder"
        case .shell: return "Shell"
        }
    }

    /// 연결된 화면 중 하나라도 노치가 있으면 true. 판별 규칙은 ChapCore 정책을 따른다.
    private static var hasNotchScreen: Bool {
        NSScreen.screens.contains { screen in
            NotchLauncherPolicy.hasNotch(topSafeAreaInset: screen.safeAreaInsets.top)
        }
    }

    private func showAbout() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showAbout()
        }
    }

    /// 키 캡슐 + 동작 설명 한 쌍. Behavior 섹션의 상시 단축키 안내에 쓰인다.
    private func shortcutHint(key: String, action: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(DS.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DS.border.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(action)
                .font(.caption)
                .foregroundColor(DS.textSecondary)
        }
    }

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

                        HStack(spacing: 16) {
                            shortcutHint(key: "⌥ .", action: "Open menu")
                            shortcutHint(key: "⌥ ,", action: "Open Settings")
                            shortcutHint(key: "⌥ (key)", action: "Launch site")
                        }
                        .padding(.top, 2)
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

                        Toggle("Notch Launcher", isOn: $vm.notchLauncherEnabled)
                            .disabled(!Self.hasNotchScreen)
                            .help(
                                "Show the launcher list in a panel under the notch. "
                                    + "The status bar menu keeps working either way."
                            )
                            .onChange(of: vm.notchLauncherEnabled) { _, _ in onSave() }

                        Picker("Notch Style", selection: $vm.notchPanelStyle) {
                            Text("Black").tag(NotchPanelStyle.black)
                            Text("Iceberg").tag(NotchPanelStyle.iceberg)
                        }
                        .pickerStyle(.segmented)
                        .disabled(!Self.hasNotchScreen || !vm.notchLauncherEnabled)
                        .onChange(of: vm.notchPanelStyle) { _, _ in onSave() }

                        if !Self.hasNotchScreen {
                            Label(
                                "This Mac has no notch display, so the notch launcher "
                                    + "is unavailable.",
                                systemImage: "info.circle"
                            )
                            .font(.caption)
                            .foregroundColor(DS.textSecondary)
                        }
                    }

                    Section("Menu") {
                        HStack(alignment: .center) {
                            Text("Sections")
                            Spacer()
                            HStack(spacing: 6) {
                                ForEach(LaunchType.allCases, id: \.self) { type in
                                    MenuSectionChip(
                                        title: Self.menuSectionName(type),
                                        isOn: !vm.hiddenMenuLaunchTypes.contains(type),
                                        action: { toggleMenuSection(type) })
                                }
                            }
                        }
                        Label(
                            "Hidden sections stay launchable with their Option shortcuts.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundColor(DS.textSecondary)
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
                Button(action: showAbout) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .help("About Chap")
                .accessibilityLabel("About Chap")
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

private struct MenuSectionChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isOn ? DS.accent : DS.textTertiary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    isOn ? DS.accentSoft : (isHovered ? DS.border.opacity(0.25) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isOn ? DS.accent.opacity(0.6) : DS.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Shown in the menu" : "Hidden from the menu")
        .accessibilityLabel("\(title) menu section")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .onHover { isHovered = $0 }
    }
}

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
