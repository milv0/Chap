import Cocoa
import SwiftUI
import UniformTypeIdentifiers

struct SiteConfigView: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
    var isNew: Bool = false
    @State private var hoveredSizeSelection: Int?
    @State private var isSizePresetPopoverPresented = false
    @State private var reservedKeyAlert = false
    @State private var reservedKeyChar = ""
    @State private var sizeEditingDisplayIdentifier: String?
    @State private var sizeEditingDisplayName: String?
    @FocusState private var nameFieldFocused: Bool
    /// Numeric draft state: width/height text while user is typing.
    /// nil means "not currently editing" → display computed value.
    @State private var widthDraft: String?
    @State private var heightDraft: String?
    @FocusState private var widthFocused: Bool
    @FocusState private var heightFocused: Bool
    @FocusState private var scriptFocused: Bool
    @State private var scriptEditorFrame = CGRect.zero
    var onSave: (() -> Void)?

    var body: some View {
        ScrollView {
            CardSection {
                formContent
                    .frame(maxWidth: 420, alignment: .leading)
            }
            .padding(.leading, DS.paddingSmall)
            .padding(.trailing, DS.padding)
            .padding(.vertical, DS.paddingSmall)
        }
        .disabled(!isEditing)
        .coordinateSpace(name: "SiteConfigForm")
        .onPreferenceChange(ScriptEditorFramePreferenceKey.self) { frame in
            scriptEditorFrame = frame
        }
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                guard site.launchType == .shell,
                    scriptFocused,
                    !scriptEditorFrame.contains(value.location)
                else { return }
                scriptFocused = false
            }
        )
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DS.spacing) {
            nameSection
            launchTypeSection
            SiteLaunchFields(
                site: $site,
                isEditing: $isEditing,
                browseForApp: browseForApp,
                browseFolder: browseFolder,
                scriptFocused: $scriptFocused
            )
            shortcutSection
            windowConfiguration
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            TextField("Site name", text: $site.name)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding(.horizontal, DS.paddingSmall)
                .padding(.vertical, 10)
                .background(DS.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Launch Type")
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            PillPicker(selection: $site.launchType)
        }
    }

    private var shortcutSection: some View {
        InputField(
            label: "Shortcut (⌥ +)",
            text: Binding(
                get: { site.shortcut ?? "" },
                set: { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = trimmed.isEmpty ? nil : String(trimmed.prefix(1)).uppercased()
                    if let key, [".", ","].contains(key) {
                        reservedKeyAlert = true
                        reservedKeyChar = key
                        return
                    }
                    site.shortcut = key
                }
            ),
            placeholder: "예: T → ⌥T"
        )
        .alert("Reserved Shortcut", isPresented: $reservedKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("⌥\(reservedKeyChar) is reserved for system use.")
        }
    }

    @ViewBuilder
    private var windowConfiguration: some View {
        if site.launchType != .shell {
            SiteWindowConfigView(
                site: $site,
                isEditing: $isEditing,
                hoveredSizeSelection: $hoveredSizeSelection,
                isSizePresetPopoverPresented: $isSizePresetPopoverPresented,
                sizeEditingDisplayIdentifier: $sizeEditingDisplayIdentifier,
                sizeEditingDisplayName: $sizeEditingDisplayName,
                widthDraft: $widthDraft,
                heightDraft: $heightDraft,
                widthFocused: $widthFocused,
                heightFocused: $heightFocused
            )
        }
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

// MARK: - Size Preset Popover

struct SizePresetPopover: View {
    let presets: [WindowSizePreset]
    let selectedSelection: Int
    @Binding var hoveredSelection: Int?
    let currentCustomSizeText: String
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                row(selection: 0, title: "Custom", sizeText: currentCustomSizeText)
                Divider()
                ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                    row(
                        selection: index + 1,
                        title: preset.label,
                        sizeText: preset.ratioText
                    )
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 360)
    }

    private func row(selection: Int, title: String, sizeText: String) -> some View {
        let isHovered = hoveredSelection == selection
        let isSelected = selectedSelection == selection

        return HStack(spacing: 6) {
            Text(title)
                .font(DS.bodyFont)
                .foregroundColor(DS.textPrimary)
                .lineLimit(1)
            Spacer()
            if !sizeText.isEmpty {
                Text(sizeText)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textTertiary)
                    .lineLimit(1)
            }
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.accent)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(isHovered ? DS.accentSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoveredSelection = selection
            } else if hoveredSelection == selection {
                hoveredSelection = nil
            }
        }
        .onTapGesture {
            onSelect(selection)
        }
    }
}
