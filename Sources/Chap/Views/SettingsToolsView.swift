import AppKit
import SwiftUI

// MARK: - Tools Tab

/// Settings > Tools 탭. Chap이 하는 "일"들의 설정: Quick Note, Lights Out, Mirror.
/// 노치 탭은 노치 모양·배치만 다루고, 기능의 단축키·동작은 모두 여기에 모은다
/// (노치가 없는 Mac에서도 같은 설정을 쓴다).
struct ToolsSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    private var quickNoteConflictMessage: String? {
        guard let key = vm.notchQuickNoteShortcut,
            let conflict = QuickNoteShortcutPolicy.conflict(for: key, sites: vm.sites)
        else { return nil }
        return QuickNoteShortcutPolicy.conflictMessage(conflict, key: key)
    }

    private var lightsOutConflictMessage: String? {
        guard let key = vm.lightsOutShortcut,
            let conflict = LightsOutPolicy.conflict(
                for: key, sites: vm.sites, quickNoteKey: vm.notchQuickNoteShortcut)
        else { return nil }
        return QuickNoteShortcutPolicy.conflictMessage(conflict, key: key)
    }

    private func reveal(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    var body: some View {
        SettingsFormPage {
            Section {
                SettingsRow(
                    title: "Shortcut", subtitle: "Opens the note window under the notch.",
                    conflictMessage: quickNoteConflictMessage,
                    help: "Press ⌥ and this key anywhere. Clear it to turn the shortcut off."
                ) {
                    OptionKeyField(
                        key: $vm.notchQuickNoteShortcut,
                        accessibilityLabel: "Quick Note shortcut key")
                }
                .onChange(of: vm.notchQuickNoteShortcut) { _, _ in onSave() }

                SettingsRow(
                    title: "Backups",
                    subtitle: "The last ten versions, kept before each overwrite.",
                    help: "Opens the folder in Finder."
                ) {
                    Button("Show in Finder") { reveal(QuickNoteStore().backupDirectoryURL) }
                        .controlSize(.small)
                }
            } header: {
                SettingsSectionHeader(
                    title: "Quick Note", systemImage: "note.text",
                    note: "Saved as you type at ~/Library/Application Support/Chap/QuickNote.txt.")
            }

            Section {
                SettingsRow(
                    title: "Shortcut", subtitle: "Covers every screen in black.",
                    conflictMessage: lightsOutConflictMessage,
                    help: "Press ⌥ and this key anywhere. Clear it to turn the shortcut off; "
                        + "the menu bar item stays."
                ) {
                    OptionKeyField(
                        key: $vm.lightsOutShortcut, accessibilityLabel: "Lights Out shortcut key")
                }
                .onChange(of: vm.lightsOutShortcut) { _, _ in onSave() }

                SettingsRow(
                    title: "Come Back With",
                    subtitle: "Forgot it? Press any key five times quickly.",
                    help: "Type a letter to change the key, or clear it for Esc."
                ) {
                    TextField(
                        "",
                        text: Binding(
                            get: { LightsOutPolicy.label(for: vm.lightsOutUnlockKey) },
                            set: { newValue in
                                vm.lightsOutUnlockKey = LightsOutPolicy.keyAfterEditing(
                                    currentKey: vm.lightsOutUnlockKey, newText: newValue)
                            }),
                        prompt: Text("Esc")
                    )
                    .keyCapField(width: 48)
                    .accessibilityLabel("Lights Out unlock key")
                }
                .onChange(of: vm.lightsOutUnlockKey) { _, _ in onSave() }
            } header: {
                SettingsSectionHeader(
                    title: "Lights Out", systemImage: "moon.fill",
                    note: "A cover, not a lock: no password. "
                        + "Use macOS Lock Screen (⌃⌘Q) to secure your Mac.")
            }

            Section {
                SettingsRow(
                    title: "Camera",
                    subtitle: "Turns on only while the mirror is open. Nothing is recorded.",
                    help: "macOS asks for camera access the first time you open the mirror."
                ) {
                    Button("Privacy Settings…") {
                        if let url = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
            } header: {
                SettingsSectionHeader(
                    title: "Mirror", systemImage: "web.camera",
                    note: "Check your camera from the notch strip before a call.")
            }
        }
    }
}
