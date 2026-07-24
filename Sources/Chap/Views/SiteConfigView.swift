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
    @FocusState private var nameFieldFocused: Bool
    var onSave: (() -> Void)?
    private let dropdownControlWidth: CGFloat = 180

    private let sizePresets = WindowSizePresets.all

    private var selectedSizePreset: WindowSizePreset? {
        WindowSizePresets.preset(withID: activeSizePresetID)
    }

    private var previewSizePreset: WindowSizePreset? {
        if let hoveredSizeSelection {
            return sizePreset(for: hoveredSizeSelection)
        }
        return selectedSizePreset
    }

    private var activeSizePresetID: String? {
        if WindowSizePresets.preset(withID: site.windowSizePreset) != nil {
            return site.windowSizePreset
        }
        return nil
    }

    private var selectedSizeSelection: Int {
        guard let activeSizePresetID else { return 0 }
        return sizePresets.firstIndex { $0.id == activeSizePresetID }.map { $0 + 1 } ?? 0
    }

    private var previewWidth: Int {
        fittedPreviewSize.width
    }

    private var previewHeight: Int {
        fittedPreviewSize.height
    }

    private var requestedPreviewWidth: Int {
        if let preset = previewSizePreset, let screen = selectedPreviewScreen {
            return windowSize(for: preset, appliedTo: site, on: screen).width
        }
        return site.width
    }

    private var requestedPreviewHeight: Int {
        if let preset = previewSizePreset, let screen = selectedPreviewScreen {
            return windowSize(for: preset, appliedTo: site, on: screen).height
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

    private var displayedWindowSize: (width: Int, height: Int) {
        guard let preset = selectedSizePreset else {
            return (site.width, site.height)
        }
        guard let screen = selectedPreviewScreen else {
            return windowSize(for: preset, on: nil)
        }
        return windowSize(for: preset, appliedTo: site, on: screen)
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
                            get: { selectedDisplayTag },
                            set: { newTag in
                                let currentSizePresetID = activeSizePresetID
                                isEditing = true
                                applyDisplaySelection(tag: newTag)
                                if let currentSizePresetID {
                                    applySize(forPresetID: currentSizePresetID)
                                }
                            }
                        )
                    ) {
                        Text("Auto (cursor screen)").tag("Auto")
                        ForEach(NSScreen.screens, id: \.self) { screen in
                            Text(displayLabel(for: screen))
                                .tag(displayUUID(for: screen) ?? screen.localizedName)
                        }
                    }
                    .labelsHidden()
                    .frame(width: dropdownControlWidth, alignment: .leading)
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
                            get: { "\(displayedWindowSize.width)" },
                            set: { newValue in
                                let currentSize = displayedWindowSize
                                // 표시값과 동일한 값이 다시 커밋되는 경우(포커스 이동/Enter 등)엔
                                // 프리셋을 풀지 않는다. 실제 사용자가 값을 바꿨을 때만 Custom으로 전환.
                                guard let parsed = Int(newValue), parsed != currentSize.width
                                else { return }
                                isEditing = true
                                site.windowSizePreset = nil
                                site.height = currentSize.height
                                site.width = max(100, parsed)
                            }),
                        placeholder: ""
                    )
                    .frame(width: 80)

                    InputField(
                        label: "Height",
                        text: Binding(
                            get: { "\(displayedWindowSize.height)" },
                            set: { newValue in
                                let currentSize = displayedWindowSize
                                guard let parsed = Int(newValue), parsed != currentSize.height
                                else { return }
                                isEditing = true
                                site.windowSizePreset = nil
                                site.width = currentSize.width
                                site.height = max(100, parsed)
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
                    width: previewWidth, height: previewHeight,
                    selectedIdentifier: site.displayIdentifier,
                    selectedName: site.displayName,
                    onSelect: { selectDisplay($0) }
                )
                .frame(maxWidth: .infinity, minHeight: 100)
                .id(
                    "\(previewWidth)-\(previewHeight)-\(site.displayIdentifier ?? site.displayName ?? "auto")"
                )
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
                Spacer(minLength: 6)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.textTertiary)
            }
            .padding(.horizontal, 8)
            .frame(width: dropdownControlWidth, height: 26, alignment: .leading)
            .background(DS.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DS.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isSizePresetPopoverPresented, arrowEdge: .bottom) {
            SizePresetPopover(
                presets: sizePresets,
                selectedSelection: selectedSizeSelection,
                hoveredSelection: $hoveredSizeSelection,
                currentCustomSizeText: "\(site.width)x\(site.height) pt",
                onSelect: { selection in
                    isEditing = true
                    hoveredSizeSelection = nil
                    isSizePresetPopoverPresented = false
                    if selection == 0 {
                        let currentSize = displayedWindowSize
                        site.windowSizePreset = nil
                        site.width = currentSize.width
                        site.height = currentSize.height
                        return
                    }
                    applySize(for: selection)
                }
            )
            .frame(width: dropdownControlWidth)
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

    /// 현재 Picker에서 선택 상태로 표시할 태그. UUID 우선, 없으면(구버전 config)
    /// 연결된 화면 중 이름이 일치하는 것의 UUID로 해석, 그마저 없으면 "Auto".
    private var selectedDisplayTag: String {
        if let id = site.displayIdentifier, !id.isEmpty,
            NSScreen.screens.contains(where: { displayUUID(for: $0) == id })
        {
            return id
        }
        if let name = site.displayName,
            let screen = NSScreen.screens.first(where: { $0.localizedName == name })
        {
            return displayUUID(for: screen) ?? name
        }
        return "Auto"
    }

    /// Picker 선택 태그를 site.displayIdentifier/displayName에 반영.
    /// UUID(식별)와 name(표시·폴백)을 함께 저장한다.
    private func applyDisplaySelection(tag: String) {
        if tag == "Auto" {
            site.displayIdentifier = nil
            site.displayName = nil
            return
        }
        if let screen = NSScreen.screens.first(where: { displayUUID(for: $0) == tag }) {
            site.displayIdentifier = tag
            site.displayName = screen.localizedName
        } else if let screen = NSScreen.screens.first(where: { $0.localizedName == tag }) {
            // UUID를 못 얻는 화면(폴백 태그가 이름인 경우)
            site.displayIdentifier = nil
            site.displayName = screen.localizedName
        }
    }

    /// 같은 localizedName을 가진 화면이 여러 대면 "(1)", "(2)"로 구분해 표시.
    private func displayLabel(for screen: NSScreen) -> String {
        let name = screen.localizedName
        let sameName = NSScreen.screens.filter { $0.localizedName == name }
        guard sameName.count > 1, let index = sameName.firstIndex(of: screen) else { return name }
        return "\(name) (\(index + 1))"
    }

    /// 미니맵 등에서 NSScreen(또는 Auto=nil)으로 디스플레이를 선택할 때 공용 처리.
    /// Picker와 동일하게 displayIdentifier(UUID)+displayName을 함께 세팅하고,
    /// 활성 프리셋이 있으면 새 화면 기준으로 크기를 재계산한다.
    private func selectDisplay(_ screen: NSScreen?) {
        let currentSizePresetID = activeSizePresetID
        isEditing = true
        if let screen {
            site.displayIdentifier = displayUUID(for: screen)
            site.displayName = screen.localizedName
        } else {
            site.displayIdentifier = nil
            site.displayName = nil
        }
        if let currentSizePresetID {
            applySize(forPresetID: currentSizePresetID)
        }
    }

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

    private func applySize(for selection: Int) {
        guard let preset = sizePreset(for: selection) else { return }
        applySize(for: preset)
    }

    private func applySize(forPresetID id: String) {
        guard let preset = WindowSizePresets.preset(withID: id) else { return }
        applySize(for: preset)
    }

    private func applySize(for preset: WindowSizePreset) {
        let fittedSize: (width: Int, height: Int)
        if let screen = selectedPreviewScreen {
            fittedSize = windowSize(for: preset, appliedTo: site, on: screen)
        } else {
            fittedSize = windowSize(for: preset, on: nil)
        }
        site.windowSizePreset = preset.id
        site.width = fittedSize.width
        site.height = fittedSize.height
    }

    private func sizePreset(for selection: Int) -> WindowSizePreset? {
        guard selection > 0, selection <= sizePresets.count else { return nil }
        return sizePresets[selection - 1]
    }

}

private struct SizePresetPopover: View {
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
