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
    /// App 항목 제목에 보여 줄 실제 앱 아이콘. 못 읽으면 nil이라 app.fill 네모로 돌아간다.
    @State private var appIconImage: NSImage?
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
        .task(id: appIconPath) { await loadAppIcon() }
        .onChange(of: quickNoteShortcut) { _, _ in clearRejectedShortcutMessageIfResolved() }
        .onChange(of: coverScreensShortcut) { _, _ in clearRejectedShortcutMessageIfResolved() }
    }

    // MARK: - Launcher Section

    private var launcherSection: some View {
        Section {
            // 타입은 사이드바 섹션에서 이미 정해진다. 편집 화면은 섹션 제목으로 알려 주기만 한다.
            HStack(spacing: 16) {
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
                .frame(width: 190)

                SiteLaunchFields(
                    site: $site,
                    browseForApp: browseForApp,
                    browseFolder: browseFolder
                )
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                guard isNew, !didAutofocusName else { return }
                didAutofocusName = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    nameFieldFocused = true
                }
            }
        } header: {
            // 사이드바 섹션 이름(URL · App · Finder)과 같은 말로 이 항목의 종류만 알린다.
            // App은 경로가 맞으면 실제 앱 아이콘을, 못 읽으면 지금의 네모(app.fill)를 그대로 둔다.
            if site.launchType == .app,
                let icon = appIconImage ?? appIconPath.flatMap(AppIconLoader.cachedIcon)
            {
                Label {
                    Text(typeTitle)
                } icon: {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
            } else {
                SettingsSectionHeader(title: typeTitle, systemImage: typeSymbol)
            }
        }
    }

    /// 아이콘을 읽을 App 경로. .app으로 끝나는 경로만 쓴다(폴더 경로면 폴더 아이콘이 나오므로).
    /// 실제로 있는지 확인과 읽기는 AppIconLoader가 utility queue에서 한다.
    private var appIconPath: String? {
        guard site.launchType == .app,
            let path = site.appPath?.trimmingCharacters(in: .whitespacesAndNewlines),
            path.hasSuffix(".app")
        else { return nil }
        return path
    }

    private func loadAppIcon() async {
        guard let path = appIconPath else {
            appIconImage = nil
            return
        }
        appIconImage = AppIconLoader.cachedIcon(forAppPath: path)
        let icon = await AppIconLoader.icon(forAppPath: path)
        guard !Task.isCancelled else { return }
        appIconImage = icon
    }

    private var typeTitle: String {
        switch site.launchType {
        case .url: return "URL"
        case .app: return "App"
        case .finder: return "Finder"
        }
    }

    private var typeSymbol: String {
        switch site.launchType {
        // 아래 Window 섹션이 macwindow를 쓰므로 URL 제목은 링크 모양으로 구분한다.
        case .url: return "link"
        case .app: return "app.fill"
        case .finder: return "folder.fill"
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
