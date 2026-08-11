import Cocoa
import SwiftUI

/// Window and display configuration section extracted from SiteConfigView.
/// Includes display picker, Follow Cursor button, size preset, width/height fields, and minimap.
struct SiteWindowConfigView: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
    @Binding var hoveredSizeSelection: Int?
    @Binding var isSizePresetPopoverPresented: Bool
    @Binding var sizeEditingDisplayIdentifier: String?
    @Binding var sizeEditingDisplayName: String?
    @Binding var widthDraft: String?
    @Binding var heightDraft: String?
    var widthFocused: FocusState<Bool>.Binding
    var heightFocused: FocusState<Bool>.Binding

    private let dropdownControlWidth: CGFloat = 180
    private let sizePresets = WindowSizePresets.all

    // MARK: - Computed Properties

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
        let presetID = currentDisplaySizeOverride?.windowSizePreset ?? site.windowSizePreset
        if WindowSizePresets.preset(withID: presetID) != nil {
            return presetID
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
            return previewSize(for: preset, on: screen).width
        }
        return displayedWindowSize.width
    }

    private var requestedPreviewHeight: Int {
        if let preset = previewSizePreset, let screen = selectedPreviewScreen {
            return previewSize(for: preset, on: screen).height
        }
        return displayedWindowSize.height
    }

    private var selectedPreviewScreen: NSScreen? {
        if hasExplicitDisplaySelection(site) {
            return targetScreen(for: site)
        }
        return sizeEditingScreen ?? targetScreen(for: site)
    }

    private var sizeEditingScreen: NSScreen? {
        if let id = sizeEditingDisplayIdentifier, !id.isEmpty,
            let screen = NSScreen.screens.first(where: { displayUUID(for: $0) == id })
        {
            return screen
        }
        if let name = sizeEditingDisplayName, !name.isEmpty {
            let matches = NSScreen.screens.filter { $0.localizedName == name }
            if matches.count == 1 {
                return matches[0]
            }
        }
        return nil
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
        if let override = currentDisplaySizeOverride, let screen = selectedPreviewScreen {
            return effectiveWindowSize(for: override, on: screen)
        }
        guard let preset = selectedSizePreset else {
            return (site.width, site.height)
        }
        guard let screen = selectedPreviewScreen else {
            return windowSize(for: preset, on: nil)
        }
        return windowSize(for: preset, appliedTo: site, on: screen)
    }

    private var currentDisplaySizeOverrideIndex: Int? {
        guard let screen = selectedPreviewScreen else { return nil }
        return displaySizeOverrideIndex(
            displayIdentifier: displayUUID(for: screen),
            displayName: screen.localizedName,
            among: site.displaySizeOverrides)
    }

    private var currentDisplaySizeOverride: DisplaySizeOverride? {
        guard let index = currentDisplaySizeOverrideIndex else { return nil }
        return site.displaySizeOverrides[index]
    }

    private var selectedDisplayTag: String {
        if let id = site.displayIdentifier, !id.isEmpty,
            NSScreen.screens.contains(where: { displayUUID(for: $0) == id })
        {
            return id
        }
        if let name = site.displayName {
            let matches = NSScreen.screens.filter { $0.localizedName == name }
            if matches.count == 1, let screen = matches.first {
                return displayUUID(for: screen) ?? name
            }
        }
        if let screen = targetScreen(for: site) {
            return displayUUID(for: screen) ?? screen.localizedName
        }
        return "Auto"
    }

    private var displayWarningText: String? {
        guard site.displayName != nil || site.displayIdentifier != nil else { return nil }
        if let id = site.displayIdentifier, !id.isEmpty,
            NSScreen.screens.contains(where: { displayUUID(for: $0) == id })
        {
            return nil
        }
        guard let name = site.displayName, !name.isEmpty else {
            return "Selected display is disconnected — please reselect"
        }
        let matches = NSScreen.screens.filter { $0.localizedName == name }
        if matches.count == 1 { return nil }
        if matches.count > 1 {
            return "Multiple '\(name)' displays — please reselect"
        }
        return "'\(name)' is disconnected"
    }

    private var sizePresetButtonText: String {
        guard let preset = selectedSizePreset else { return "Custom" }
        return preset.label
    }

    // MARK: - Body

    var body: some View {
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
                                isEditing = true
                                applyDisplaySelection(tag: newTag)
                            }
                        )
                    ) {
                        ForEach(NSScreen.screens, id: \.self) { screen in
                            Text(displayLabel(for: screen))
                                .tag(displayUUID(for: screen) ?? screen.localizedName)
                        }
                    }
                    .labelsHidden()
                    .frame(width: dropdownControlWidth, alignment: .leading)
                    Button {
                        toggleFollowCursor()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cursorarrow")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Follow Cursor")
                                .font(DS.captionFont)
                        }
                        .foregroundColor(
                            hasExplicitDisplaySelection(site) ? DS.textSecondary : DS.accent
                        )
                        .padding(.horizontal, 8)
                        .frame(width: dropdownControlWidth, height: 24, alignment: .leading)
                        .background(
                            hasExplicitDisplaySelection(site) ? DS.surfaceBg : DS.accentSoft
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    hasExplicitDisplaySelection(site) ? DS.border : DS.accent,
                                    lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    if let warning = displayWarningText {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text(warning)
                                .font(DS.captionFont)
                                .foregroundColor(.orange)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Size Preset")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    sizePresetDropdown
                    Text(previewSizeText)
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                    if currentDisplaySizeOverrideIndex != nil {
                        HStack(spacing: 6) {
                            Text("Display-specific")
                                .font(DS.captionFont)
                                .foregroundColor(DS.textTertiary)
                            Button("Use Site Default") {
                                removeCurrentDisplaySizeOverride()
                            }
                            .buttonStyle(.plain)
                            .font(DS.captionFont)
                            .foregroundColor(DS.accent)
                        }
                    }
                }

                HStack(spacing: DS.paddingSmall) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .font(DS.captionFont)
                            .foregroundColor(DS.textSecondary)
                        TextField(
                            "",
                            text: Binding(
                                get: { widthDraft ?? "\(displayedWindowSize.width)" },
                                set: { widthDraft = $0 }
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
                        .focused(widthFocused)
                        .onSubmit { commitWidthDraft() }
                        .onChange(of: widthFocused.wrappedValue) { _, focused in
                            if !focused { commitWidthDraft() }
                        }
                    }
                    .frame(width: 80)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .font(DS.captionFont)
                            .foregroundColor(DS.textSecondary)
                        TextField(
                            "",
                            text: Binding(
                                get: { heightDraft ?? "\(displayedWindowSize.height)" },
                                set: { heightDraft = $0 }
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
                        .focused(heightFocused)
                        .onSubmit { commitHeightDraft() }
                        .onChange(of: heightFocused.wrappedValue) { _, focused in
                            if !focused { commitHeightDraft() }
                        }
                    }
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
                    selectedIdentifier: site.displayIdentifier,
                    selectedName: site.displayName,
                    focusedIdentifier: sizeEditingDisplayIdentifier,
                    focusedName: sizeEditingDisplayName,
                    previewSizeForScreen: { minimapPreviewSize(for: $0) },
                    previewLabelForScreen: { minimapPreviewLabel(for: $0) },
                    onPreviewSelect: { focusSizeEditing(on: $0) }
                )
                .frame(maxWidth: .infinity, minHeight: 100)
                .id(
                    "\(previewWidth)-\(previewHeight)-\(site.displayIdentifier ?? site.displayName ?? "auto")-\(sizeEditingDisplayIdentifier ?? sizeEditingDisplayName ?? "cursor")"
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Size Preset Dropdown

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
                currentCustomSizeText:
                    "\(displayedWindowSize.width)x\(displayedWindowSize.height) pt",
                onSelect: { selection in
                    isEditing = true
                    hoveredSizeSelection = nil
                    isSizePresetPopoverPresented = false
                    if selection == 0 {
                        let currentSize = displayedWindowSize
                        updateCurrentSize(
                            windowSizePreset: nil,
                            width: currentSize.width,
                            height: currentSize.height)
                        return
                    }
                    applySize(for: selection)
                }
            )
            .frame(width: dropdownControlWidth)
            .onDisappear { hoveredSizeSelection = nil }
        }
    }

    // MARK: - Actions

    private func applyDisplaySelection(tag: String) {
        sizeEditingDisplayIdentifier = nil
        sizeEditingDisplayName = nil
        if tag == "Auto" {
            site.displayIdentifier = nil
            site.displayName = nil
            return
        }
        if let screen = NSScreen.screens.first(where: { displayUUID(for: $0) == tag }) {
            site.displayIdentifier = tag
            site.displayName = screen.localizedName
        } else if let screen = NSScreen.screens.first(where: { $0.localizedName == tag }) {
            site.displayIdentifier = nil
            site.displayName = screen.localizedName
        }
    }

    private func displayLabel(for screen: NSScreen) -> String {
        let name = screen.localizedName
        let sameName = NSScreen.screens.filter { $0.localizedName == name }
        guard sameName.count > 1, let index = sameName.firstIndex(of: screen) else { return name }
        return "\(name) (\(index + 1))"
    }

    private func selectDisplay(_ screen: NSScreen?) {
        isEditing = true
        sizeEditingDisplayIdentifier = nil
        sizeEditingDisplayName = nil
        if let screen {
            site.displayIdentifier = displayUUID(for: screen)
            site.displayName = screen.localizedName
        } else {
            site.displayIdentifier = nil
            site.displayName = nil
        }
    }

    private func toggleFollowCursor() {
        if hasExplicitDisplaySelection(site) {
            selectDisplay(nil)
            return
        }
        selectDisplay(
            selectedPreviewScreen ?? cursorScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }

    private func focusSizeEditing(on screen: NSScreen) {
        guard !hasExplicitDisplaySelection(site) else { return }
        sizeEditingDisplayIdentifier = displayUUID(for: screen)
        sizeEditingDisplayName = screen.localizedName
    }

    private func applySize(for selection: Int) {
        guard let preset = sizePreset(for: selection) else { return }
        applySize(for: preset)
    }

    private func applySize(for preset: WindowSizePreset) {
        let fittedSize: (width: Int, height: Int)
        if let screen = selectedPreviewScreen {
            fittedSize = previewSize(for: preset, on: screen)
        } else {
            fittedSize = windowSize(for: preset, on: nil)
        }
        updateCurrentSize(
            windowSizePreset: preset.id,
            width: fittedSize.width,
            height: fittedSize.height)
    }

    private func sizePreset(for selection: Int) -> WindowSizePreset? {
        guard selection > 0, selection <= sizePresets.count else { return nil }
        return sizePresets[selection - 1]
    }

    private func commitWidthDraft() {
        guard let draft = widthDraft else { return }
        widthDraft = nil
        let currentSize = displayedWindowSize
        guard let parsed = Int(draft), parsed >= 100, parsed != currentSize.width else {
            return
        }
        isEditing = true
        updateCurrentSize(windowSizePreset: nil, width: parsed, height: currentSize.height)
    }

    private func commitHeightDraft() {
        guard let draft = heightDraft else { return }
        heightDraft = nil
        let currentSize = displayedWindowSize
        guard let parsed = Int(draft), parsed >= 100, parsed != currentSize.height else {
            return
        }
        isEditing = true
        updateCurrentSize(windowSizePreset: nil, width: currentSize.width, height: parsed)
    }

    private func previewSize(for preset: WindowSizePreset, on screen: NSScreen) -> (
        width: Int, height: Int
    ) {
        windowSize(for: preset, referenceScreen: screen, fittingScreen: screen)
    }

    private func minimapPreviewSize(for screen: NSScreen) -> (width: Int, height: Int) {
        if hoveredSizeSelection != nil, isSelectedPreviewScreen(screen),
            let preset = previewSizePreset
        {
            return previewSize(for: preset, on: screen)
        }
        return effectiveWindowSize(for: site, on: screen)
    }

    private func minimapPreviewLabel(for screen: NSScreen) -> String {
        if let hoveredSizeSelection, isSelectedPreviewScreen(screen) {
            return sizePreset(for: hoveredSizeSelection)?.label ?? "Custom"
        }
        if let override = displaySizeOverride(for: site, on: screen) {
            return WindowSizePresets.preset(withID: override.windowSizePreset)?.label ?? "Custom"
        }
        return selectedSizePreset?.label ?? "Custom"
    }

    private func isSelectedPreviewScreen(_ screen: NSScreen) -> Bool {
        guard let selectedScreen = selectedPreviewScreen else { return false }
        if screen === selectedScreen {
            return true
        }
        if let selectedIdentifier = displayUUID(for: selectedScreen),
            let identifier = displayUUID(for: screen)
        {
            return identifier == selectedIdentifier
        }
        return screen.localizedName == selectedScreen.localizedName
    }

    private func updateCurrentSize(windowSizePreset: String?, width: Int, height: Int) {
        if let index = currentDisplaySizeOverrideIndex {
            site.displaySizeOverrides[index].windowSizePreset = windowSizePreset
            site.displaySizeOverrides[index].width = width
            site.displaySizeOverrides[index].height = height
            return
        }
        if hasExplicitDisplaySelection(site) {
            site.windowSizePreset = windowSizePreset
            site.width = width
            site.height = height
            return
        }
        if let screen = selectedPreviewScreen {
            site.displaySizeOverrides.append(
                DisplaySizeOverride(
                    displayName: screen.localizedName,
                    displayIdentifier: displayUUID(for: screen),
                    windowSizePreset: windowSizePreset,
                    width: width,
                    height: height))
            return
        }
        site.windowSizePreset = windowSizePreset
        site.width = width
        site.height = height
    }

    private func removeCurrentDisplaySizeOverride() {
        guard let index = currentDisplaySizeOverrideIndex else { return }
        isEditing = true
        site.displaySizeOverrides.remove(at: index)
    }
}
