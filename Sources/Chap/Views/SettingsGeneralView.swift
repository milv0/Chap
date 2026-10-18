import Cocoa
import SwiftUI

// MARK: - General Tab

/// Settings > General 탭. 앱 자체에 관한 것만: App / Launching / Menu Bar, 그리고 버전 표시.
/// 기능(Quick Note·Cover Screens·Mirror) 설정은 Tools 탭, 노치 모양은 Notch 탭에 있다.
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
        }
    }

    private func showAbout() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showAbout()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsFormPage {
                // 앱 자체: 언제 켜지고 어떻게 업데이트되는지.
                Section {
                    SettingsToggleRow(
                        title: "Open at Login", subtitle: "Start Chap when you sign in.",
                        isOn: $vm.launchAtLogin
                    )
                    .onChange(of: vm.launchAtLogin) { _, _ in onSave() }

                    SettingsToggleRow(
                        title: "Check for Updates Automatically",
                        subtitle: "Once a day. You decide when to install.",
                        help: "Checks once per day and notifies you when an update is available.",
                        isOn: Binding(
                            get: { updateController.automaticallyChecksForUpdates },
                            set: { updateController.setAutomaticallyChecksForUpdates($0) })
                    )
                    .disabled(!updateController.canCheckForUpdates)
                } header: {
                    SettingsSectionHeader(title: "App", systemImage: "app.badge")
                }

                // 사이트를 여는 방식: 단축키와 창 위치 미리보기.
                Section {
                    SettingsToggleRow(
                        title: "Option-Key Triggers",
                        subtitle: "⌥. opens the menu, ⌥, opens Settings, ⌥(key) launches a site.",
                        help:
                            "Turn this off temporarily when another app needs Option-key combinations. "
                            + "Quick Note and Cover Screens shortcuts pause too.",
                        isOn: $vm.optionShortcutsEnabled
                    )
                    .onChange(of: vm.optionShortcutsEnabled) { _, _ in onSave() }

                    SettingsToggleRow(
                        title: "Guide Window",
                        subtitle: "Shows where a window will land while it opens.",
                        isOn: $vm.showGuideWindow
                    )
                    .onChange(of: vm.showGuideWindow) { _, _ in onSave() }
                } header: {
                    SettingsSectionHeader(
                        title: "Launching", systemImage: "arrow.up.forward.app",
                        note:
                            "Per-site keys live in Launchers; Quick Note and Cover Screens keys in Tools."
                    )
                }

                Section {
                    SettingsRow(
                        title: "Status Bar Icon",
                        subtitle: "Turns Chap blue while Keep Awake runs."
                    ) {
                        HStack(spacing: 8) {
                            ForEach(StatusBarIconChoice.allCases, id: \.self) { choice in
                                StatusBarIconChoiceButton(
                                    choice: choice,
                                    isSelected: vm.statusBarIcon == choice,
                                    action: { vm.statusBarIcon = choice })
                            }
                        }
                    }
                    .onChange(of: vm.statusBarIcon) { _, _ in onSave() }

                    SettingsRow(
                        title: "Menu Sections",
                        subtitle: "Hidden sections stay launchable with their ⌥ keys."
                    ) {
                        HStack(spacing: 6) {
                            ForEach(LaunchType.allCases, id: \.self) { type in
                                MenuSectionChip(
                                    title: Self.menuSectionName(type),
                                    isOn: !vm.hiddenMenuLaunchTypes.contains(type),
                                    action: { toggleMenuSection(type) })
                            }
                        }
                    }
                } header: {
                    SettingsSectionHeader(title: "Menu Bar", systemImage: "menubar.rectangle")
                }
            }

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
            case .seal:
                // 메뉴 막대와 같은 실루엣을 1pt = 1칸 그대로(보간 없이) 보여 준다.
                Image(nsImage: AppDelegate.sealStatusBarImage())
                    .renderingMode(.template)
                    .interpolation(.none)
            }
        }
        .foregroundColor(color)
        .frame(width: choice == .seal ? 26 : 20, height: 20)
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
        case .seal: return "Seal icon"
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
