import Cocoa
import SwiftUI
import UniformTypeIdentifiers

struct SiteConfigView: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
    var isNew: Bool = false
    @State private var sizeSelection = 0
    @State private var hoveredSizeSelection: Int?
    @State private var isSizePresetPopoverPresented = false
    @State private var suppressOnChange = false
    @State private var reservedKeyAlert = false
    @State private var reservedKeyChar = ""
    @FocusState private var nameFieldFocused: Bool
    var onSave: (() -> Void)?

    fileprivate struct SizePreset: Identifiable {
        let label: String
        let widthRatio: CGFloat
        let heightRatio: CGFloat

        var id: String { label }
    }

    private let sizePresets: [SizePreset] = [
        SizePreset(label: "Small 40%", widthRatio: 0.40, heightRatio: 0.40),
        SizePreset(label: "Medium 55%", widthRatio: 0.55, heightRatio: 0.55),
        SizePreset(label: "Large 70%", widthRatio: 0.70, heightRatio: 0.70),
        SizePreset(label: "Max 90%", widthRatio: 0.90, heightRatio: 0.90),
        SizePreset(label: "Wide 75x50%", widthRatio: 0.75, heightRatio: 0.50),
        SizePreset(label: "Wide 90x55%", widthRatio: 0.90, heightRatio: 0.55),
        SizePreset(label: "Tall 45x75%", widthRatio: 0.45, heightRatio: 0.75),
        SizePreset(label: "Tall 55x85%", widthRatio: 0.55, heightRatio: 0.85),
    ]

    private var selectedSizePreset: SizePreset? {
        sizePreset(for: sizeSelection)
    }

    private var previewSizePreset: SizePreset? {
        sizePreset(for: hoveredSizeSelection ?? sizeSelection)
    }

    private var previewWidth: Int {
        fittedPreviewSize.width
    }

    private var previewHeight: Int {
        fittedPreviewSize.height
    }

    private var requestedPreviewWidth: Int {
        if let preset = previewSizePreset {
            return size(for: preset, on: selectedPreviewScreen).width
        }
        return site.width
    }

    private var requestedPreviewHeight: Int {
        if let preset = previewSizePreset {
            return size(for: preset, on: selectedPreviewScreen).height
        }
        return site.height
    }

    private var selectedPreviewScreen: NSScreen? {
        targetScreen(for: site)
    }

    private var fittedPreviewSize: (width: Int, height: Int) {
        guard let screen = selectedPreviewScreen else {
            return (requestedPreviewWidth, requestedPreviewHeight)
        }
        return fittedWindowSize(
            width: requestedPreviewWidth, height: requestedPreviewHeight, on: screen)
    }

    private var previewSizeText: String {
        "\(previewWidth)x\(previewHeight) pt"
    }

    var body: some View {
        ScrollView {
            CardSection {
                VStack(alignment: .leading, spacing: DS.spacing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(DS.captionFont)
                            .foregroundColor(DS.textSecondary)
                        TextField("Site name", text: $site.name)
                            .textFieldStyle(.plain)
                            .font(DS.bodyFont)
                            .padding(DS.paddingSmall)
                            .background(DS.surfaceBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(DS.border, lineWidth: 1)
                            )
                            .focused($nameFieldFocused)
                    }
                    .onAppear {
                        if isNew {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                nameFieldFocused = true
                            }
                        }
                    }

                    InputField(
                        label: "Shortcut (⌥ +)",
                        text: Binding(
                            get: { site.shortcut ?? "" },
                            set: { newValue in
                                let key =
                                    newValue.isEmpty ? nil : String(newValue.prefix(1)).uppercased()
                                if let k = key, [".", ","].contains(k) {
                                    reservedKeyAlert = true
                                    reservedKeyChar = k
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type")
                            .font(DS.captionFont)
                            .foregroundColor(DS.textSecondary)
                        PillPicker(selection: $site.launchType)
                    }

                    switch site.launchType {
                    case .url:
                        urlFields
                    case .app:
                        appFields
                    case .finder:
                        finderFields
                    case .shell:
                        shellFields
                    }
                }
            }
            .padding(.horizontal, DS.padding)
            .padding(.top, DS.paddingSmall)
            .padding(.bottom, DS.padding)
        }
        .disabled(!isEditing)
        .onAppear { detectSizePreset() }
    }

    // MARK: - URL Fields

    private var urlFields: some View {
        Group {
            InputField(
                label: "URL",
                text: Binding(
                    get: { site.url },
                    set: { newURL in
                        site.url = newURL
                        if site.name == Defaults.newSiteName || site.name.isEmpty,
                            let host = URL(string: newURL)?.host
                        {
                            site.name =
                                host.replacingOccurrences(of: "www.", with: "")
                                .components(separatedBy: ".").first?.capitalized ?? host
                        }
                    }
                ),
                placeholder: "https://"
            )
            windowFields
        }
    }

    // MARK: - App Fields

    private var appFields: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("App")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                HStack(spacing: 8) {
                    TextField(
                        "/Applications/...",
                        text: Binding(
                            get: { site.appPath ?? "" },
                            set: { newPath in
                                site.appPath = newPath
                                if !newPath.isEmpty {
                                    let appName = URL(fileURLWithPath: newPath)
                                        .deletingPathExtension().lastPathComponent
                                    if site.name == Defaults.newSiteName || site.name.isEmpty {
                                        site.name = appName
                                    }
                                }
                            }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(DS.bodyFont)
                    .padding(DS.paddingSmall)
                    .background(DS.surfaceBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.border, lineWidth: 1)
                    )

                    Button(action: browseForApp) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12))
                            .foregroundColor(DS.accent)
                            .padding(8)
                            .background(DS.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            windowFields
        }
    }

    // MARK: - Window Fields

    private var windowFields: some View {
        HStack(alignment: .top, spacing: DS.spacing) {
            VStack(alignment: .leading, spacing: DS.paddingSmall) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    Picker(
                        "",
                        selection: Binding(
                            get: { site.displayName ?? "Auto" },
                            set: { newDisplay in
                                site.displayName = newDisplay == "Auto" ? nil : newDisplay
                                if sizeSelection > 0 {
                                    DispatchQueue.main.async { applySize() }
                                }
                            }
                        )
                    ) {
                        Text("Auto (cursor screen)").tag("Auto")
                        ForEach(NSScreen.screens, id: \.localizedName) { screen in
                            Text(screen.localizedName).tag(screen.localizedName)
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Size Preset")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    sizePresetDropdown
                    Text(previewSizeText)
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                }

                HStack(spacing: DS.paddingSmall) {
                    InputField(
                        label: "Width",
                        text: Binding(
                            get: { "\(site.width)" },
                            set: { newValue in
                                sizeSelection = 0
                                site.width = max(100, Int(newValue) ?? site.width)
                            }),
                        placeholder: ""
                    )
                    .frame(width: 80)

                    InputField(
                        label: "Height",
                        text: Binding(
                            get: { "\(site.height)" },
                            set: { newValue in
                                sizeSelection = 0
                                site.height = max(100, Int(newValue) ?? site.height)
                            }),
                        placeholder: ""
                    )
                    .frame(width: 80)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Display Preview")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    Spacer()
                    Text(previewSizeText)
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                }
                MinimapSwiftUI(
                    width: previewWidth, height: previewHeight, displayName: $site.displayName
                )
                .frame(maxWidth: .infinity, minHeight: 100)
                .id("\(previewWidth)-\(previewHeight)-\(site.displayName ?? "auto")")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var sizePresetDropdown: some View {
        Button {
            hoveredSizeSelection = nil
            isSizePresetPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(sizePresetButtonText)
                    .font(DS.bodyFont)
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.textTertiary)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(DS.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DS.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .popover(isPresented: $isSizePresetPopoverPresented, arrowEdge: .bottom) {
            SizePresetPopover(
                presets: sizePresets,
                selectedSelection: sizeSelection,
                hoveredSelection: $hoveredSizeSelection,
                currentCustomSizeText: "\(site.width)x\(site.height) pt",
                onSelect: { selection in
                    sizeSelection = selection
                    hoveredSizeSelection = nil
                    isSizePresetPopoverPresented = false
                    if !suppressOnChange {
                        DispatchQueue.main.async { applySize() }
                    }
                }
            )
            .frame(width: 220)
            .onDisappear { hoveredSizeSelection = nil }
        }
    }

    private var sizePresetButtonText: String {
        guard let preset = selectedSizePreset else { return "Custom" }
        return preset.label
    }

    // MARK: - Finder Fields

    private var finderFields: some View {
        Group {
            HStack(alignment: .bottom) {
                InputField(
                    label: "Folder",
                    text: Binding(
                        get: { site.folderPath ?? "" },
                        set: { newPath in
                            site.folderPath = newPath
                            if site.name == Defaults.newSiteName || site.name.isEmpty,
                                !newPath.isEmpty
                            {
                                site.name = URL(fileURLWithPath: newPath).lastPathComponent
                            }
                        }
                    ),
                    placeholder: "~/Documents"
                )
                Button(action: browseFolder) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .frame(height: 30)
            }
            windowFields
        }
    }

    // MARK: - Shell Fields

    private var shellFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Script")
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
            TextEditor(
                text: Binding(
                    get: { site.script ?? "" },
                    set: { site.script = $0 }
                )
            )
            .font(DS.monoFont)
            .frame(minHeight: 120)
            .padding(8)
            .background(DS.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusSmall)
                    .stroke(DS.border, lineWidth: 1)
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
        // 이전 앱 이름과 같거나 기본값이면 새 앱 이름으로 변경
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

    private func detectSizePreset() {
        DispatchQueue.main.async {
            suppressOnChange = true
            var detectedSize = 0
            for (i, preset) in sizePresets.enumerated() {
                let presetSize = size(for: preset, on: selectedPreviewScreen)
                if site.width == presetSize.width && site.height == presetSize.height {
                    detectedSize = i + 1
                    break
                }
            }
            sizeSelection = detectedSize
            suppressOnChange = false
        }
    }

    private func applySize() {
        guard let preset = selectedSizePreset else { return }
        let fittedSize = size(for: preset, on: selectedPreviewScreen)
        DispatchQueue.main.async {
            site.width = fittedSize.width
            site.height = fittedSize.height
        }
    }

    private func sizePreset(for selection: Int) -> SizePreset? {
        guard selection > 0, selection <= sizePresets.count else { return nil }
        return sizePresets[selection - 1]
    }

    private func size(for preset: SizePreset, on screen: NSScreen?) -> (width: Int, height: Int) {
        guard let screen else {
            return (Defaults.defaultWidth, Defaults.defaultHeight)
        }
        let width = max(100, Int((screen.visibleFrame.width * preset.widthRatio).rounded(.down)))
        let height = max(100, Int((screen.visibleFrame.height * preset.heightRatio).rounded(.down)))
        return fittedWindowSize(width: width, height: height, on: screen)
    }
}

private struct SizePresetPopover: View {
    let presets: [SiteConfigView.SizePreset]
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
                        sizeText: ""
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
            Text(sizeText.isEmpty ? title : "\(title) (\(sizeText))")
                .font(DS.bodyFont)
                .foregroundColor(DS.textPrimary)
                .lineLimit(1)
            Spacer()
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
