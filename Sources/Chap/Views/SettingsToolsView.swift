import AppKit
import SwiftUI

// MARK: - Tools Tab

/// Settings > Tools 탭. 노치 없이도 쓰는 기능(⌥ 단축키·메뉴바로 여는 것)의 설정: Quick Note, Cover Screens,
/// 그리고 macOS 스크린샷 저장 폴더 안내(읽기만 하고, 바꾸는 곳은 스크린샷 앱).
/// 노치에서만 쓰는 기능(Mirror 등)은 Notch 탭에 둔다. 빈 섹션은 만들지 않는다.
struct ToolsSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    private var quickNoteConflictMessage: String? {
        guard let key = vm.notchQuickNoteShortcut,
            let conflict = QuickNoteShortcutPolicy.conflict(for: key, sites: vm.sites)
        else { return nil }
        return QuickNoteShortcutPolicy.conflictMessage(conflict, key: key)
    }

    private var coverScreensConflictMessage: String? {
        guard let key = vm.coverScreensShortcut,
            let conflict = CoverScreensPolicy.conflict(
                for: key, sites: vm.sites, quickNoteKey: vm.notchQuickNoteShortcut)
        else { return nil }
        return QuickNoteShortcutPolicy.conflictMessage(conflict, key: key)
    }

    /// 문구 저장은 마지막 입력 0.6초 뒤에 한 번. 키마다 config를 다시 쓰지 않는다.
    @State private var messageSave: DispatchWorkItem?
    /// 스크린샷 앱에서 위치를 바꾸고 돌아오면 Chap이 다시 활성화되며 새 경로를 읽는다.
    @State private var screenshotFolder = ScreenshotShelf.directory()

    private func scheduleMessageSave() {
        messageSave?.cancel()
        let work = DispatchWorkItem { commitMessage() }
        messageSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func commitMessage() {
        messageSave?.cancel()
        let cleaned = CoverScreensPolicy.cleanedMessage(vm.coverScreensMessage)
        if cleaned != vm.coverScreensMessage { vm.coverScreensMessage = cleaned }
        onSave()
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
                    conflictMessage: coverScreensConflictMessage,
                    help: "Press ⌥ and this key anywhere. Clear it to turn the shortcut off; "
                        + "the menu bar item stays."
                ) {
                    OptionKeyField(
                        key: $vm.coverScreensShortcut,
                        accessibilityLabel: "Cover Screens shortcut key")
                }
                .onChange(of: vm.coverScreensShortcut) { _, _ in onSave() }

                // 가림막 시계 아래에 띄울 한 줄. 비우면 아무것도 띄우지 않는다.
                SettingsRow(
                    title: "Message",
                    subtitle: "Shown under the clock while your screens are covered.",
                    help: "One line, up to \(CoverScreensPolicy.messageMaxLength) characters. "
                        + "Leave it empty for none."
                ) {
                    TextField(
                        "Message",
                        text: Binding(
                            get: { vm.coverScreensMessage ?? "" },
                            set: { newValue in
                                // 입력 중에는 앞뒤 공백을 지우지 않아야 단어 사이 띄어쓰기가 된다.
                                let limited = String(
                                    newValue.prefix(CoverScreensPolicy.messageMaxLength))
                                vm.coverScreensMessage =
                                    limited.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? nil : limited
                            }),
                        prompt: Text("Back in 10 minutes")
                    )
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .accessibilityLabel("Cover Screens message")
                }
                // 키 입력마다 저장하지 않고, 칸을 떠날 때·Enter를 칠 때 정리해 저장한다.
                .onSubmit { commitMessage() }
                .onChange(of: vm.coverScreensMessage) { _, _ in scheduleMessageSave() }

                // 걷는 법은 정해져 있어 바꿀 칸이 없다: ⌥ 한 번, 잊으면 아무 키나 10번.
                SettingsRow(
                    title: "Come Back",
                    subtitle: "Tap ⌥ Option. Forgot? Press any key 10 times quickly.",
                    help: "Tap Option by itself, with no other key. Holding it down while you "
                        + "press another key does not count."
                ) {
                    Text("⌥ Option")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .accessibilityLabel("Option key")
                }
            } header: {
                SettingsSectionHeader(
                    title: "Cover Screens", systemImage: "moon.fill",
                    note: "A cover, not a lock: no password. "
                        + "Use macOS Lock Screen (⌃⌘Q) to secure your Mac.")
            }

            Section {
                SettingsRow(
                    title: "Folder",
                    subtitle: screenshotFolderSubtitle,
                    help: screenshotFolder.path
                ) {
                    HStack(spacing: 6) {
                        Button("Show in Finder") { NSWorkspace.shared.open(screenshotFolder) }
                            .controlSize(.small)
                        Button("Change…") { ScreenshotShelf.openScreenshotApp() }
                            .controlSize(.small)
                            .help(
                                "Opens the Screenshot app. Choose Options → Other Location… "
                                    + "to pick or make a folder, and Chap follows along.")
                    }
                }
            } header: {
                SettingsSectionHeader(
                    title: "Screenshots", systemImage: "camera.viewfinder",
                    note: "Pick one in the Screenshot app (Options → Other Location…). "
                        + "Chap only reads it.")
            }
            .onAppear(perform: refreshScreenshotFolder)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.didBecomeActiveNotification)
            ) { _ in refreshScreenshotFolder() }

        }
    }

    // MARK: Screenshots

    private func refreshScreenshotFolder() {
        let folder = ScreenshotShelf.directory()
        if folder != screenshotFolder { screenshotFolder = folder }
    }

    private var screenshotFolderSubtitle: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = ScreenshotShelfPolicy.displayPath(screenshotFolder.path, home: home)
        guard ScreenshotShelfPolicy.isDesktop(screenshotFolder.path, home: home) else {
            return path
        }
        // 데스크톱이면 다른 이미지도 선반에 올라온다. 전용 폴더를 권하되 강요하지 않는다.
        return "\(path) · every image here joins the shelf"
    }
}
