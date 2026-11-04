import Cocoa
import SwiftUI
import UniformTypeIdentifiers

struct SiteConfigView: View {
    @Binding var site: Site
    var isNew: Bool = false
    /// Tools에서 이미 배정한 키. 런처 입력에서는 이 키를 쓸 수 없다.
    var quickNoteShortcut: String?
    var coverScreensShortcut: String?
    @State private var hoveredSizeSelection: Int?
    @State private var reservedKeyAlert = false
    @State private var reservedKeyChar = ""
    /// 거부한 입력은 site에 쓰지 않고, 사용자가 왜 안 됐는지 바로 보게 한다.
    @State private var rejectedShortcutMessage: String?
    @State private var sizeEditingDisplayIdentifier: String?
    @State private var sizeEditingDisplayName: String?
    @FocusState private var nameFieldFocused: Bool
    @State private var didAutofocusName = false
    /// Numeric draft state: width/height text while user is typing.
    /// nil means "not currently editing" → display computed value.
    @State private var widthDraft: String?
    @State private var heightDraft: String?
    @FocusState private var widthFocused: Bool
    @FocusState private var heightFocused: Bool
    var onSave: (() -> Bool)?

    var body: some View {
        SettingsFormPage(minimumHorizontalMargin: 12) {
            launcherSection
            windowConfiguration
        }
        .alert("Reserved Shortcut", isPresented: $reservedKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("⌥\(reservedKeyChar) is reserved for system use.")
        }
        .onChange(of: quickNoteShortcut) { _, _ in clearRejectedShortcutMessageIfResolved() }
        .onChange(of: coverScreensShortcut) { _, _ in clearRejectedShortcutMessageIfResolved() }
    }

    // MARK: - Launcher Section

    private var launcherSection: some View {
        Section {
            // Type과 Name을 한 줄에. 둘 다 짧아 따로 두면 오른쪽이 비어 보인다.
            HStack(spacing: 16) {
                Picker("Launch Type", selection: $site.launchType) {
                    Text("URL").tag(LaunchType.url)
                    Text("App").tag(LaunchType.app)
                    Text("Finder").tag(LaunchType.finder)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                HStack(spacing: 8) {
                    Text("Name")
                        .foregroundColor(DS.textSecondary)
                        .fixedSize()
                    TextField("Site name", text: $site.name)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFieldFocused)
                        .accessibilityLabel("Name")
                }
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                guard isNew, !didAutofocusName else { return }
                didAutofocusName = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    nameFieldFocused = true
                }
            }

            SiteLaunchFields(
                site: $site,
                browseForApp: browseForApp,
                browseFolder: browseFolder
            )
        } header: {
            SettingsSectionHeader(title: "Launcher", systemImage: "square.grid.2x2")
        }
    }

    private var activeShortcutConflict: QuickNoteShortcutPolicy.Conflict? {
        QuickNoteShortcutPolicy.launcherConflict(
            for: site.shortcut,
            quickNoteKey: quickNoteShortcut,
            coverScreensKey: coverScreensShortcut)
    }

    private var shortcutErrorMessage: String? {
        if let conflict = activeShortcutConflict,
            let key = QuickNoteShortcutPolicy.normalized(site.shortcut)
        {
            return QuickNoteShortcutPolicy.conflictMessage(conflict, key: key)
        }
        return rejectedShortcutMessage
    }

    private var shortcutBinding: Binding<String?> {
        Binding(
            get: { site.shortcut },
            set: { newValue in
                let key = QuickNoteShortcutPolicy.normalized(newValue)
                if let key, [".", ","].contains(key) {
                    reservedKeyAlert = true
                    reservedKeyChar = key
                    return
                }
                if let key,
                    let conflict = QuickNoteShortcutPolicy.launcherConflict(
                        for: key,
                        quickNoteKey: quickNoteShortcut,
                        coverScreensKey: coverScreensShortcut)
                {
                    rejectedShortcutMessage = QuickNoteShortcutPolicy.conflictMessage(
                        conflict, key: key)
                    return
                }
                rejectedShortcutMessage = nil
                site.shortcut = key
            }
        )
    }

    private func clearRejectedShortcutMessageIfResolved() {
        if activeShortcutConflict == nil { rejectedShortcutMessage = nil }
    }

    private var windowConfiguration: some View {
        SiteWindowConfigView(
            site: $site,
            shortcut: shortcutBinding,
            shortcutErrorMessage: shortcutErrorMessage,
            hoveredSizeSelection: $hoveredSizeSelection,
            sizeEditingDisplayIdentifier: $sizeEditingDisplayIdentifier,
            sizeEditingDisplayName: $sizeEditingDisplayName,
            widthDraft: $widthDraft,
            heightDraft: $heightDraft,
            widthFocused: $widthFocused,
            heightFocused: $heightFocused
        )
    }

    // MARK: - Actions

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let newAppName = url.deletingPathExtension().lastPathComponent
        let oldAppName = site.appPath.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        if site.name == Defaults.newSiteName || site.name.isEmpty || site.name == oldAppName {
            site.name = newAppName
        }
        site.appPath = url.path
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        guard panel.runModal() == .OK, let url = panel.url else { return }
        site.folderPath = url.path
        if site.name == Defaults.newSiteName || site.name.isEmpty {
            site.name = url.lastPathComponent
        }
    }
}
