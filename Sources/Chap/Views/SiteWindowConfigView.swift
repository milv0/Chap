import Cocoa
import SwiftUI

/// Window and display configuration section extracted from SiteConfigView.
/// Includes display picker, Follow Cursor button, size preset, width/height fields, and minimap.
struct SiteWindowConfigView: View {
    @Binding var site: Site
    @Binding var isEditing: Bool
    @Binding var hoveredSizeSelection: Int?
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

    /// 프리셋을 고른 동안 보이는 실제 크기. 목록에서 뺀 프리셋(Focus)은 이름도 함께 보여준다.
    private var sizeSummaryText: String {
        guard let preset = selectedSizePreset, selectedSizeSelection < 0 else {
            return previewSizeText
        }
        return "\(preset.label) · \(previewSizeText)"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacing) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionHeader(title: "Window", systemImage: "macwindow")
                windowGroup
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionHeader(title: "Preview", systemImage: "rectangle.on.rectangle")
                MinimapSwiftUI(
                    selectedIdentifier: site.displayIdentifier,
                    selectedName: site.displayName,
                    focusedIdentifier: sizeEditingDisplayIdentifier,
                    focusedName: sizeEditingDisplayName,
                    previewSizeForScreen: { minimapPreviewSize(for: $0) },
                    previewLabelForScreen: { minimapPreviewLabel(for: $0) },
                    onPreviewSelect: { handleTopologySelection($0) }
                )
                .frame(maxWidth: .infinity, minHeight: 100)
                .id(
                    "\(previewWidth)-\(previewHeight)-\(site.displayIdentifier ?? site.displayName ?? "auto")"
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Display·Follow Cursor·Reuse·Size를 다른 탭과 같은 묶음 줄로 둔다. 컨트롤은 모두 오른쪽 끝.
    private var windowGroup: some View {
        VStack(spacing: 0) {
            groupRow {
                SettingsRow(
                    title: "Display",
                    subtitle: displayWarningText ?? "Where the window opens.",
                    help:
                        "Pick a screen, or turn on Follow Cursor to use the one under your pointer."
                ) {
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
                    .frame(width: dropdownControlWidth)
                }
            }
            groupDivider
            groupRow {
                SettingsToggleRow(
                    title: "Follow Cursor",
                    subtitle: "Opens on the screen under your pointer.",
                    help: "Click a display in the preview to set its size while this is on.",
                    isOn: Binding(
                        get: { !hasExplicitDisplaySelection(site) },
                        set: { _ in
                            isEditing = true
                            toggleFollowCursor()
                        }
                    )
                )
            }
            if site.launchType == .url {
                groupDivider
                groupRow {
                    SettingsToggleRow(
                        title: "Reuse Existing Window",
                        subtitle: "Brings back the window this launcher opened.",
                        help: "Reuse only the Chrome app window created by this launchable.",
                        isOn: $site.reuseExistingWindow
                    )
                }
            }
            groupDivider
            groupRow {
                VStack(alignment: .leading, spacing: 8) {
                    // 제목 줄 오른쪽: 프리셋이면 실제 크기를 작게(올린 칸의 크기로 바뀐다), Custom이면 W·H 입력.
                    SettingsRow(title: "Size", subtitle: "Recalculated for the screen at launch.") {
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
            }
        }
        .background(DS.surfaceBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DS.border, lineWidth: 1))
    }

    private func groupRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
    }

    private var groupDivider: some View {
        Divider().padding(.leading, 12)
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
        isEditing = true
        hoveredSizeSelection = nil
        if selection == 0 {
            let currentSize = displayedWindowSize
            updateCurrentSize(
                windowSizePreset: nil, width: currentSize.width, height: currentSize.height)
            return
        }
        applySize(for: selection)
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

    private func handleTopologySelection(_ screen: NSScreen) {
        if hasExplicitDisplaySelection(site) {
            selectDisplay(screen)
        } else {
            focusSizeEditing(on: screen)
        }
    }

    private func focusSizeEditing(on screen: NSScreen) {
        isEditing = true
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
