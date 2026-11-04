import Cocoa
import SwiftUI

/// Window and display configuration section extracted from SiteConfigView.
/// Includes display picker, Follow Cursor button, size preset, width/height fields, and minimap.
struct SiteWindowConfigView: View {
    @Binding var site: Site
    @Binding var shortcut: String?
    var shortcutErrorMessage: String?
    @Binding var hoveredSizeSelection: Int?
    @Binding var sizeEditingDisplayIdentifier: String?
    @Binding var sizeEditingDisplayName: String?
    @Binding var widthDraft: String?
    @Binding var heightDraft: String?
    var widthFocused: FocusState<Bool>.Binding
    var heightFocused: FocusState<Bool>.Binding

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
        // 목록에서 뺀 프리셋(예: Focus)은 어느 칸도 고르지 않는다. Custom도 아니다.
        return sizePresets.firstIndex { $0.id == activeSizePresetID }.map { $0 + 1 } ?? -1
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
        if !hasExplicitDisplaySelection(site), let override = currentDisplaySizeOverride,
            let screen = selectedPreviewScreen
        {
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
        guard !hasExplicitDisplaySelection(site), let screen = selectedPreviewScreen else {
            return nil
        }
        return displaySizeOverrideIndex(
            displayIdentifier: displayUUID(for: screen),
            displayName: screen.localizedName,
            among: site.displaySizeOverrides)
    }

    private var currentDisplaySizeOverride: DisplaySizeOverride? {
        guard let index = currentDisplaySizeOverrideIndex else { return nil }
        return site.displaySizeOverrides[index]
    }

    private static let unresolvedDisplayTag = "ChapSavedDisplayUnavailable"

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
        if hasExplicitDisplaySelection(site) {
            return Self.unresolvedDisplayTag
        }
        if let screen = targetScreen(for: site) {
            return displayUUID(for: screen) ?? screen.localizedName
        }
        return "Auto"
    }

    private var unresolvedDisplayLabel: String {
        let name = site.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty, NSScreen.screens.filter({ $0.localizedName == name }).count > 1 {
            return "\(name) — Ambiguous"
        }
        return "\(name.isEmpty ? "Saved Display" : name) — Unavailable"
    }

    private var displayWarningText: String? {
        guard hasExplicitDisplaySelection(site) else { return nil }
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

    /// 프리셋을 고른 동안 보이는 실제 크기. 목록에서 뺀 프리셋(Focus)은 이름도 함께 보여준다.
    private var sizeSummaryText: String {
        guard let preset = selectedSizePreset, selectedSizeSelection < 0 else {
            return previewSizeText
        }
        return "\(preset.label) · \(previewSizeText)"
    }

    // MARK: - Form Sections

    var body: some View {
        windowSection
    }

    private var windowSection: some View {
        Section {
            SettingsRow(
                title: "Shortcut",
                conflictMessage: shortcutErrorMessage,
                help: "Press ⌥ and this key anywhere to launch. Clear it to turn the shortcut off."
            ) {
                OptionKeyField(
                    key: $shortcut,
                    accessibilityLabel: "Launcher shortcut key",
                    hasError: shortcutErrorMessage != nil)
            }

            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(
                    title: "Display",
                    help: "Pick a screen, or use Follow Cursor for the one under your pointer."
                ) {
                    HStack(spacing: 10) {
                        Picker(
                            "Display",
                            selection: Binding(
                                get: { selectedDisplayTag },
                                set: { newTag in applyDisplaySelection(tag: newTag) }
                            )
                        ) {
                            if selectedDisplayTag == Self.unresolvedDisplayTag {
                                Text(unresolvedDisplayLabel)
                                    .tag(Self.unresolvedDisplayTag)
                            }
                            ForEach(NSScreen.screens, id: \.self) { screen in
                                Text(displayLabel(for: screen))
                                    .tag(displayUUID(for: screen) ?? screen.localizedName)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .frame(width: 150, alignment: .trailing)
                        .accessibilityLabel("Display")
                        .disabled(!hasExplicitDisplaySelection(site))

                        Text("Follow Cursor")
                        Toggle(
                            "Follow Cursor",
                            isOn: Binding(
                                get: { !hasExplicitDisplaySelection(site) },
                                set: { _ in toggleFollowCursor() }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .help("Click a display in Preview to set its size while this is on.")
                    }
                }

                if let displayWarningText {
                    Label(displayWarningText, systemImage: "exclamationmark.triangle.fill")
                        .font(DS.captionFont)
                        .foregroundColor(DS.danger)
                        .help(displayWarningText)
                }
            }

            if site.launchType == .url {
                SettingsToggleRow(
                    title: "Reuse Existing Window",
                    help: "Bring back only the Chrome app window created by this launcher.",
                    isOn: $site.reuseExistingWindow
                )
            }

            sizeRow

            // Preview는 Size 바로 아래에 둔다. 섹션을 따로 두면 상자가 하나 더 생겨 화면이 번잡해진다.
            VStack(alignment: .leading, spacing: 8) {
                SettingsRow(
                    title: "Preview",
                    help: hasExplicitDisplaySelection(site)
                        ? "Click a display to open the window there."
                        : "Click a display to set its own size while following the cursor."
                ) {
                    Text(
                        hasExplicitDisplaySelection(site)
                            ? "Click a display to select it" : "Click a display to size it"
                    )
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
                    onPreviewSelect: { handleTopologySelection($0) }
                )
                .id(
                    "\(previewWidth)-\(previewHeight)-\(site.displayIdentifier ?? site.displayName ?? "auto")"
                )
            }
        } header: {
            SettingsSectionHeader(title: "Window", systemImage: "macwindow")
        }
    }

    private var sizeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsRow(title: "Size", help: "Recalculated for the screen at launch.") {
                if selectedSizePreset != nil
                    || hoveredSizeSelection.map({ $0 > 0 }) == true
                {
                    Text(sizeSummaryText)
                        .font(DS.captionFont)
                        .foregroundColor(DS.textTertiary)
                        .monospacedDigit()
                } else {
                    HStack(spacing: 12) {
                        compactDimensionField(
                            label: "W",
                            text: Binding(
                                get: { widthDraft ?? "\(displayedWindowSize.width)" },
                                set: { widthDraft = $0 }
                            ),
                            focused: widthFocused,
                            commit: commitWidthDraft
                        )
                        compactDimensionField(
                            label: "H",
                            text: Binding(
                                get: { heightDraft ?? "\(displayedWindowSize.height)" },
                                set: { heightDraft = $0 }
                            ),
                            focused: heightFocused,
                            commit: commitHeightDraft
                        )
                    }
                }
            }
            .frame(minHeight: 24)

            SizePresetGrid(
                presets: sizePresets,
                selectedSelection: selectedSizeSelection,
                hoveredSelection: $hoveredSizeSelection,
                onSelect: selectSize
            )
        }
        .onDisappear {
            hoveredSizeSelection = nil
            commitDimensionDrafts()
        }
    }

    private func compactDimensionField(
        label: String,
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        commit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)

            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(DS.bodyFont)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(DS.surfaceBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.border, lineWidth: 1)
                )
                .focused(focused)
                .onSubmit { commit() }
                .onChange(of: focused.wrappedValue) { _, isFocused in
                    if !isFocused { commit() }
                }
                .accessibilityLabel(label == "W" ? "Width" : "Height")
        }
        .frame(width: 80)
    }

    // MARK: - Size Preset Dropdown

    /// 격자에서 고른 칸을 적용한다. 0은 Custom: 지금 크기를 그대로 숫자로 남긴다.
    private func selectSize(_ selection: Int) {
        hoveredSizeSelection = nil
        if selection == 0 {
            commitDimensionDrafts()
            let currentSize = displayedWindowSize
            updateCurrentSize(
                windowSizePreset: nil, width: currentSize.width, height: currentSize.height)
            return
        }
        discardDimensionDrafts()
        applySize(for: selection)
    }

    // MARK: - Actions

    private func applyDisplaySelection(tag: String) {
        commitDimensionDrafts()
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
        commitDimensionDrafts()
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

    private func handleTopologySelection(_ screen: NSScreen) {
        if hasExplicitDisplaySelection(site) {
            selectDisplay(screen)
        } else {
            focusSizeEditing(on: screen)
        }
    }

    private func focusSizeEditing(on screen: NSScreen) {
        commitDimensionDrafts()
        sizeEditingDisplayIdentifier = displayUUID(for: screen)
        sizeEditingDisplayName = screen.localizedName
    }

    private func toggleFollowCursor() {
        if hasExplicitDisplaySelection(site) {
            selectDisplay(nil)
            return
        }
        selectDisplay(
            selectedPreviewScreen ?? cursorScreen ?? NSScreen.main ?? NSScreen.screens.first)
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

    private func commitDimensionDrafts() {
        commitWidthDraft()
        commitHeightDraft()
    }

    private func discardDimensionDrafts() {
        widthDraft = nil
        heightDraft = nil
    }

    private func commitWidthDraft() {
        guard let draft = widthDraft else { return }
        widthDraft = nil
        let currentSize = displayedWindowSize
        guard let parsed = Int(draft), parsed >= 100, parsed != currentSize.width else {
            return
        }
        updateCurrentSize(windowSizePreset: nil, width: parsed, height: currentSize.height)
    }

    private func commitHeightDraft() {
        guard let draft = heightDraft else { return }
        heightDraft = nil
        let currentSize = displayedWindowSize
        guard let parsed = Int(draft), parsed >= 100, parsed != currentSize.height else {
            return
        }
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
        if !hasExplicitDisplaySelection(site),
            let override = displaySizeOverride(for: site, on: screen)
        {
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
        if hasExplicitDisplaySelection(site) {
            site.windowSizePreset = windowSizePreset
            site.width = width
            site.height = height
            return
        }
        guard let screen = selectedPreviewScreen else {
            site.windowSizePreset = windowSizePreset
            site.width = width
            site.height = height
            return
        }
        if let index = currentDisplaySizeOverrideIndex {
            site.displaySizeOverrides[index].windowSizePreset = windowSizePreset
            site.displaySizeOverrides[index].width = width
            site.displaySizeOverrides[index].height = height
        } else {
            site.displaySizeOverrides.append(
                DisplaySizeOverride(
                    displayName: screen.localizedName,
                    displayIdentifier: displayUUID(for: screen),
                    windowSizePreset: windowSizePreset,
                    width: width,
                    height: height))
        }
    }
}
