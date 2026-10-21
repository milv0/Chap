import Cocoa
import SwiftUI
import UniformTypeIdentifiers

struct SiteConfigView: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
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
    /// Numeric draft state: width/height text while user is typing.
    /// nil means "not currently editing" → display computed value.
    @State private var widthDraft: String?
    @State private var heightDraft: String?
    @FocusState private var widthFocused: Bool
    @FocusState private var heightFocused: Bool
    var onSave: (() -> Bool)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            CardSection {
                // 창이 넓어도 입력칸을 늘리지 않는다. 격자 여섯 칸이 겨우 들어가는 폭까지만.
                formContent
                    .frame(maxWidth: 460, alignment: .leading)
            }
            .padding(.leading, DS.paddingSmall)
            .padding(.trailing, DS.padding)
            .padding(.vertical, DS.paddingSmall)
        }
        .disabled(!isEditing)
        .onChange(of: quickNoteShortcut) { _, _ in clearRejectedShortcutMessageIfResolved() }
        .onChange(of: coverScreensShortcut) { _, _ in clearRejectedShortcutMessageIfResolved() }
    }

    // MARK: - Form Content

    private var formContent: some View {
        // 크기 프리셋 격자가 들어가 길어진 만큼 위쪽 입력 줄 사이는 조금 좁힌다.
        VStack(alignment: .leading, spacing: 12) {
            launchTypeSection
            nameAndShortcutRow
            launchTargetFields
            windowConfiguration
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name")
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            TextField("Site name", text: $site.name)
                .textFieldStyle(.plain)
                .font(DS.bodyFont)
                .padding(.horizontal, DS.fieldPaddingH)
                .padding(.vertical, DS.fieldPaddingV)
                .background(DS.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.fieldRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.fieldRadius)
                        .stroke(DS.border, lineWidth: 1)
                )
                .focused($nameFieldFocused)
        }
        .onAppear {
            guard isNew else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nameFieldFocused = true
            }
        }
    }

    private var launchTypeSection: some View {
        // 레이블을 알약 왼쪽에 붙여 한 줄로 둔다.
        HStack(spacing: DS.paddingSmall) {
            Text("Launch Type")
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
                .fixedSize()
            PillPicker(selection: $site.launchType)
        }
    }

    private var nameAndShortcutRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: DS.spacing) {
                nameSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                shortcutSection(isCompact: true)
                    .frame(width: 88, alignment: .center)
            }
            if let message = shortcutErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(DS.captionFont)
                    .foregroundColor(DS.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(message)
            }
        }
    }

    private var launchTargetFields: some View {
        SiteLaunchFields(
            site: $site,
            isEditing: $isEditing,
            browseForApp: browseForApp,
            browseFolder: browseFolder
        )
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

    private var shortcutBinding: Binding<String> {
        Binding(
            get: { site.shortcut ?? "" },
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

    private func shortcutSection(isCompact: Bool = false) -> some View {
        InputField(
            label: isCompact ? "Shortcut (⌥)" : "Shortcut (⌥ +)",
            text: shortcutBinding,
            placeholder: isCompact ? "–" : "예: T → ⌥T",
            alignment: isCompact ? .center : .leading,
            textAlignment: isCompact ? .center : .leading,
            fieldBackground: isCompact ? DS.accentSurface : DS.surfaceBg,
            fieldBorder: isCompact ? DS.accent.opacity(0.7) : DS.border,
            hasError: shortcutErrorMessage != nil
        )
        .alert("Reserved Shortcut", isPresented: $reservedKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("⌥\(reservedKeyChar) is reserved for system use.")
        }
    }

    private var windowConfiguration: some View {
        SiteWindowConfigView(
            site: $site,
            isEditing: $isEditing,
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
