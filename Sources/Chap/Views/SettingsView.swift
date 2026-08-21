import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import os

private enum SettingsTab: Hashable {
    case launchables
    case general
}

private struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : DS.textSecondary)
            .frame(width: 124, height: 28)
            .background(
                isSelected
                    ? DS.accent
                    : (isHovered ? DS.border.opacity(0.25) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @State private var selectedTab: SettingsTab = .launchables
    @State private var selectedIndex: Int? = nil
    @State private var showDeleteAlert = false
    @State private var showGuide = false
    @State private var isGuideEnglish = false
    @State private var showPasteJSON = false
    @State private var pasteJSONText = ""
    @State private var dropTargeted = false
    @State private var isEditing = false
    @State private var isAddingNew = false
    /// addSite로 갓 추가된, 아직 이름을 정하지 않은 사이트의 id.
    /// 선택이 벗어날 때 이 사이트가 여전히 placeholder면 폐기한다.
    @State private var pendingNewSiteID: UUID?
    @State private var searchText = ""
    @State private var suppressNextSelectionSave = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()

                ZStack {
                    mainPanel
                        .opacity(selectedTab == .launchables ? 1 : 0)
                        .allowsHitTesting(selectedTab == .launchables)
                        .disabled(selectedTab != .launchables)
                        .accessibilityHidden(selectedTab != .launchables)

                    generalTab
                        .opacity(selectedTab == .general ? 1 : 0)
                        .allowsHitTesting(selectedTab == .general)
                        .disabled(selectedTab != .general)
                        .accessibilityHidden(selectedTab != .general)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if selectedTab == .launchables {
                        siteSelectionShortcuts
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            bottomBar
        }
        .frame(minWidth: 770, minHeight: 640)
        .background(DS.surfaceBg)
        .onChange(of: selectedTab) { _, _ in
            vm.flushPendingSave()
            searchFocused = false
        }
        .onChange(of: selectedIndex) { oldValue, newValue in
            handleSelectionChange(from: oldValue, to: newValue)
        }
        .alert("Delete site?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { removeSite() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let idx = selectedIndex, idx < vm.sites.count {
                Text("This will remove \"\(vm.sites[idx].name)\".")
            }
        }
        .sheet(isPresented: $showGuide) {
            SettingsGuideSheet(
                isGuideEnglish: $isGuideEnglish,
                onClose: { showGuide = false },
                onOpenQA: { openQAFromGuide() }
            )
        }
        .alert("Validation Error", isPresented: $emptyFieldAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(emptyFieldMessage)
        }
        .sheet(isPresented: $showPasteJSON) {
            SettingsPasteJSONSheet(
                pasteJSONText: $pasteJSONText,
                onCancel: { showPasteJSON = false },
                onApply: { json in
                    SettingsConfigTransfer.applyJSONString(
                        json, vm: vm, onSuccess: handleSuccessfulImport)
                }
            )
        }
        .onDisappear { vm.flushPendingSave() }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleConfigDrop(providers)
        }
        .overlay(
            dropTargeted
                ? RoundedRectangle(cornerRadius: DS.radius)
                    .stroke(DS.accent, lineWidth: 3)
                    .padding(4)
                : nil
        )
    }

    // MARK: - Tabs

    private var settingsTabPicker: some View {
        HStack(spacing: 2) {
            SettingsTabButton(
                title: "Launchables",
                icon: "square.grid.2x2",
                isSelected: selectedTab == .launchables,
                action: { selectedTab = .launchables })
            SettingsTabButton(
                title: "General",
                icon: "gearshape",
                isSelected: selectedTab == .general,
                action: { selectedTab = .general })
        }
        .padding(2)
        .background(DS.border.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var generalTab: some View {
        GeneralSettingsView(vm: vm, onSave: saveGlobals)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(DS.textTertiary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.captionFont)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.surfaceBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .onTapGesture { searchFocused = true }

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(LaunchType.allCases, id: \.self) { type in
                        let indices = vm.sites.indices.filter {
                            vm.sites[$0].launchType == type
                                && (searchText.isEmpty
                                    || vm.sites[$0].name.localizedCaseInsensitiveContains(
                                        searchText))
                        }
                        // 검색 중이 아니면 항목이 없는 타입도 섹션을 유지해,
                        // 네 가지 실행 타입을 사이드바에서 바로 추가할 수 있게 한다.
                        if !indices.isEmpty || searchText.isEmpty {
                            Text(typeSectionTitle(type))
                                .font(DS.captionFont)
                                .foregroundColor(DS.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                            if indices.isEmpty {
                                SidebarAddRow(label: "Add \(typeSectionTitle(type))") {
                                    addSite(type: type)
                                }
                            }
                            ForEach(indices, id: \.self) { i in
                                SidebarItem(
                                    icon: sidebarIcon(for: vm.sites[i]),
                                    name: vm.sites[i].name,
                                    badge: vm.sites[i].shortcut.map { "⌥ \($0)" },
                                    isSelected: selectedIndex == i
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedIndex = i
                                    selectedTab = .launchables
                                }
                                .draggable(String(i)) {
                                    Text(vm.sites[i].name)
                                        .padding(8)
                                        .background(DS.cardBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .onDrop(
                                    of: [.plainText],
                                    delegate: SidebarDropDelegate(
                                        currentIndex: i,
                                        sites: $vm.sites,
                                        selectedIndex: $selectedIndex,
                                        onDrop: { save() }
                                    ))
                            }
                        }
                    }
                }
                .padding(DS.spacingSmall)
            }

        }
        .frame(width: 200)
    }

    // MARK: - Main Panel

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let idx = selectedIndex, idx < vm.sites.count {
                ZStack {
                    SiteConfigView(
                        site: $vm.sites[idx], isEditing: $isEditing, isNew: isAddingNew,
                        onSave: {
                            vm.cancelPendingSave()
                            save()
                        }
                    )
                    .id(vm.sites[idx].id)
                    .onChange(of: vm.sites) { _, _ in
                        if isEditing { vm.scheduleAutoSave() }
                    }

                    if !isEditing {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { isEditing = true }
                            .accessibilityLabel("Enable editing")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 28))
                        .foregroundColor(DS.textTertiary)
                    Text("Select a site to configure")
                        .font(DS.bodyFont)
                        .foregroundColor(DS.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }

        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            launchablesBottomBar
            Divider()

            ZStack {
                settingsTabPicker

                HStack(spacing: DS.spacingSmall) {
                    Spacer()

                    ToolbarIconButton(
                        icon: "questionmark.circle", color: DS.textSecondary,
                        action: { showGuide = true }
                    )
                    .help("User Guide")

                    ToolbarIconMenu(icon: "ellipsis.circle") {
                        Button("Import from File...") {
                            SettingsConfigTransfer.importConfig(
                                vm: vm, onSuccess: handleSuccessfulImport)
                        }
                        Button("Paste JSON...") {
                            pasteJSONText = ""
                            showPasteJSON = true
                        }
                        Divider()
                        Button("Export...") { SettingsConfigTransfer.exportConfig(vm: vm) }
                        Divider()
                        Button("Restart App") { restartApp() }
                        Button("Uninstall...") { uninstallApp() }
                    }
                    .help("Import, export, and app actions")

                    if selectedTab == .launchables && isEditing {
                        Text("Editing")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                    }
                }
                .padding(.horizontal, DS.paddingSmall)
            }

            // ToolbarIconButton은 탭 제스처 기반이라 키보드 단축키를 직접 못 받으므로
            // ⌘/ 는 숨김 버튼으로 연결 (아래 Return/⌘S와 같은 패턴)
            Button("") { showGuide = true }
                .keyboardShortcut("/", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)

            if selectedTab == .launchables {
                Button("") {
                    save(showAlerts: true)
                    isEditing = false
                }
                .keyboardShortcut(.return, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)

                Button("") {
                    save(showAlerts: true)
                }
                .keyboardShortcut("s", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
            }
        }
        .frame(height: 40)
    }

    private var launchablesBottomBar: some View {
        HStack(spacing: 4) {
            ToolbarIconButton(
                icon: "plus", color: DS.textSecondary, action: { addSite() })
            ToolbarIconButton(
                icon: "minus", color: DS.danger,
                action: {
                    selectedTab = .launchables
                    showDeleteAlert = true
                },
                disabled: selectedIndex == nil)

            Spacer()

            ToolbarIconButton(
                icon: "chevron.up", color: DS.textSecondary,
                action: {
                    selectedTab = .launchables
                    moveSiteUp()
                },
                disabled: !canMoveUp)
            ToolbarIconButton(
                icon: "chevron.down", color: DS.textSecondary,
                action: {
                    selectedTab = .launchables
                    moveSiteDown()
                },
                disabled: !canMoveDown)
        }
        .padding(.horizontal, 8)
        .frame(width: 200, height: 40)
    }

    // MARK: - Keyboard Shortcuts

    @ViewBuilder
    private var siteSelectionShortcuts: some View {
        ForEach(0..<min(9, vm.sites.count), id: \.self) { i in
            Button("") { selectedIndex = i }
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        Button("") { moveSelection(by: -1) }
            .keyboardShortcut(.upArrow, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)

        Button("") { moveSelection(by: 1) }
            .keyboardShortcut(.downArrow, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)

        Button("") { addSite() }
            .keyboardShortcut("n", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
    }

    /// 사이드바에 표시되는 순서 (타입별 그룹) 기준으로 이동
    private func moveSelection(by offset: Int) {
        let displayOrder = LaunchType.allCases.flatMap { type in
            vm.sites.indices.filter { vm.sites[$0].launchType == type }
        }
        guard !displayOrder.isEmpty else { return }
        guard let current = selectedIndex,
            let pos = displayOrder.firstIndex(of: current)
        else {
            selectedIndex = displayOrder.first
            return
        }
        let newPos = pos + offset
        if newPos >= 0 && newPos < displayOrder.count {
            selectedIndex = displayOrder[newPos]
        }
    }

    // MARK: - Helpers

    private func handleSelectionChange(from oldValue: Int?, to newValue: Int?) {
        vm.flushPendingSave()
        if suppressNextSelectionSave {
            suppressNextSelectionSave = false
            searchFocused = false
            return
        }
        let newlySelectedID = newValue.flatMap { idx in
            idx < vm.sites.count ? vm.sites[idx].id : nil
        }
        // addSite가 방금 만든 사이트로의 전환이면 편집 상태·추적 id를 유지한다.
        if let pendingID = pendingNewSiteID, pendingID == newlySelectedID {
            searchFocused = false
            return
        }
        isAddingNew = false
        isEditing = false
        searchFocused = false
        // 이름을 정하지 않은 채 벗어난 새 사이트는 폐기한다.
        if oldValue != newValue, let pendingID = pendingNewSiteID,
            let pendingIdx = vm.sites.firstIndex(where: { $0.id == pendingID }),
            vm.sites[pendingIdx].name == Defaults.newSiteName
        {
            pendingNewSiteID = nil
            vm.sites.remove(at: pendingIdx)
            selectedIndex = newlySelectedID.flatMap { id in
                vm.sites.firstIndex(where: { $0.id == id })
            }
            return
        }
        pendingNewSiteID = nil
        save()
    }

    private func handleConfigDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension == "json" else { return }
            DispatchQueue.main.async {
                SettingsConfigTransfer.importFromURL(
                    url, vm: self.vm, onSuccess: handleSuccessfulImport)
            }
        }
        return true
    }

    private func openQAFromGuide() {
        showGuide = false
        DispatchQueue.main.async {
            (NSApp.delegate as? AppDelegate)?.openQA()
        }
    }

    /// 새 사이트 추가. type을 주면 그 섹션에, 없으면 현재 선택된 사이트의 타입을 물려받는다.
    private func addSite(type explicitType: LaunchType? = nil) {
        selectedTab = .launchables
        // 이름을 정하지 않은 직전 placeholder가 남아 있으면 먼저 폐기해 중복 누적을 막는다.
        if let pendingID = pendingNewSiteID,
            let pendingIdx = vm.sites.firstIndex(where: { $0.id == pendingID }),
            vm.sites[pendingIdx].name == Defaults.newSiteName
        {
            vm.sites.remove(at: pendingIdx)
        }
        let type: LaunchType = {
            if let explicitType { return explicitType }
            if let idx = selectedIndex, idx < vm.sites.count {
                return vm.sites[idx].launchType
            }
            return .url
        }()
        let recommendation = InitialWindowSizeRecommendations.recommendation(for: type)
        let defaultSize = windowSize(for: recommendation, on: builtInScreen ?? cursorScreen)
        let newSite = Site(
            name: Defaults.newSiteName, url: type == .url ? "https://" : "",
            width: defaultSize.width, height: defaultSize.height,
            windowSizePreset: recommendation.sizePresetID,
            launchType: type)
        vm.sites.append(newSite)
        pendingNewSiteID = newSite.id
        isAddingNew = true
        isEditing = true
        selectedIndex = vm.sites.count - 1
    }

    private func removeSite() {
        guard let idx = selectedIndex, idx < vm.sites.count else { return }
        pendingNewSiteID = nil
        vm.sites.remove(at: idx)
        selectedIndex = vm.sites.isEmpty ? nil : min(idx, vm.sites.count - 1)
        isEditing = false
        save()
    }

    private func moveSiteUp() {
        guard let idx = selectedIndex else { return }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx), pos > 0 else { return }
        let prev = siblings[pos - 1]
        vm.sites.swapAt(idx, prev)
        selectedIndex = prev
        save()
    }

    private func moveSiteDown() {
        guard let idx = selectedIndex else { return }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx), pos < siblings.count - 1 else { return }
        let next = siblings[pos + 1]
        vm.sites.swapAt(idx, next)
        selectedIndex = next
        save()
    }

    /// 선택된 사이트와 같은 타입인 사이트들의 배열 인덱스 (사이드바 그룹 표시 순서와 일치)
    private func sameTypeIndices() -> [Int] {
        guard let idx = selectedIndex, idx < vm.sites.count else { return [] }
        let type = vm.sites[idx].launchType
        return vm.sites.indices.filter { vm.sites[$0].launchType == type }
    }

    private var canMoveUp: Bool {
        guard let idx = selectedIndex else { return false }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx) else { return false }
        return pos > 0
    }

    private var canMoveDown: Bool {
        guard let idx = selectedIndex else { return false }
        let siblings = sameTypeIndices()
        guard let pos = siblings.firstIndex(of: idx) else { return false }
        return pos < siblings.count - 1
    }

    private func typeSectionTitle(_ type: LaunchType) -> String {
        switch type {
        case .url: return "URL"
        case .app: return "App"
        case .finder: return "Finder"
        case .shell: return "Shell"
        }
    }

    private func sidebarIcon(for site: Site) -> String {
        switch site.launchType {
        case .url:
            return site.displayName == nil ? "display.2" : "display"
        case .app:
            return "app.fill"
        case .finder:
            return "folder.fill"
        case .shell:
            return "terminal.fill"
        }
    }

    @State private var emptyFieldAlert = false
    @State private var emptyFieldMessage = ""

    private func handleSuccessfulImport() {
        pendingNewSiteID = nil
        isAddingNew = false
        isEditing = false

        let validSelection: Int?
        if vm.sites.isEmpty {
            validSelection = nil
        } else if let selectedIndex, vm.sites.indices.contains(selectedIndex) {
            validSelection = selectedIndex
        } else {
            validSelection = 0
        }

        if selectedIndex != validSelection {
            suppressNextSelectionSave = true
            selectedIndex = validSelection
        }
    }

    private func save(showAlerts: Bool = false) {
        vm.cancelPendingSave()
        // Full config validation across ALL sites (not just selected)
        let config = Config(
            showGuideWindow: vm.showGuideWindow,
            launchAtLogin: vm.launchAtLogin,
            optionShortcutsEnabled: vm.optionShortcutsEnabled,
            statusBarIcon: vm.statusBarIcon,
            sites: vm.sites)
        let result = validateConfig(config)

        // For auto-saves (not user-triggered), silently skip if invalid
        if !result.isValid && !showAlerts {
            return
        }

        // For manual saves, show validation errors
        if !result.isValid {
            let errorMessages = result.errors.map { issue in
                let siteName =
                    issue.siteIndex < vm.sites.count ? vm.sites[issue.siteIndex].name : "?"
                return "• \(siteName): \(issue.message)"
            }.joined(separator: "\n")
            emptyFieldMessage = errorMessages
            emptyFieldAlert = true
            return
        }

        // Show warnings (non-blocking) only on manual save
        if showAlerts && !result.warnings.isEmpty {
            let warningMessages = result.warnings.map { issue in
                let siteName =
                    issue.siteIndex < vm.sites.count ? vm.sites[issue.siteIndex].name : "?"
                return "• \(siteName): \(issue.message)"
            }.joined(separator: "\n")
            let alert = NSAlert()
            alert.messageText = "Saved with warnings"
            alert.informativeText = warningMessages
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            // Save first, then show warning only if persistence succeeded.
            guard vm.persistCurrentState() else { return }
            alert.runModal()
            return
        }

        _ = vm.persistCurrentState()
    }

    /// 전역 설정(Guide Window, Login, Option Shortcuts, Status Bar Icon)만 저장.
    /// 편집 중인 사이트의 검증 상태와 무관하게 항상 저장되도록
    /// 사이트 목록은 마지막 저장 시점(originalSites)을 사용한다.
    private func saveGlobals() {
        let saved =
            vm.onSave?(
                SettingsPayload(
                    sites: vm.originalSites, showGuideWindow: vm.showGuideWindow,
                    launchAtLogin: vm.launchAtLogin,
                    optionShortcutsEnabled: vm.optionShortcutsEnabled,
                    statusBarIcon: vm.statusBarIcon)) ?? true
        if saved {
            vm.originalGuide = vm.showGuideWindow
            vm.originalLogin = vm.launchAtLogin
            vm.originalOptionShortcutsEnabled = vm.optionShortcutsEnabled
            vm.originalStatusBarIcon = vm.statusBarIcon
        }
    }

    private func restartApp() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.restartApp()
        }
    }

    private func uninstallApp() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.uninstallApp()
        }
    }
}

private struct StatusBarIconPreview: View {
    let choice: StatusBarIconChoice
    let color: Color

    var body: some View {
        Group {
            switch choice {
            case .default:
                if let image = NSImage(named: "StatusBarIcon") {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                }
            case .lightning:
                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundColor(color)
        .frame(width: 20, height: 20)
    }
}

private struct StatusBarIconChoiceButton: View {
    let choice: StatusBarIconChoice
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var title: String {
        switch choice {
        case .default: return "Default icon"
        case .lightning: return "Lightning icon"
        }
    }

    private var backgroundColor: Color {
        if isSelected { return DS.accentSoft }
        if isHovered { return DS.border.opacity(0.25) }
        return .clear
    }

    private var borderColor: Color {
        isSelected ? DS.accent : DS.border
    }

    var body: some View {
        Button(action: action) {
            StatusBarIconPreview(
                choice: choice,
                color: isSelected ? DS.accent : DS.textSecondary
            )
            .frame(width: 64, height: 34)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovered = $0 }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Form {
                    Section("Behavior") {
                        Toggle("Guide Window", isOn: $vm.showGuideWindow)
                            .onChange(of: vm.showGuideWindow) { _, _ in onSave() }

                        Toggle("Open at Login", isOn: $vm.launchAtLogin)
                            .onChange(of: vm.launchAtLogin) { _, _ in onSave() }

                        Toggle(
                            "Enable Chap Option-Key Triggers",
                            isOn: $vm.optionShortcutsEnabled
                        )
                        .help(
                            "Disable when another workflow needs Chap's Option-key combinations."
                        )
                        .onChange(of: vm.optionShortcutsEnabled) { _, _ in onSave() }

                        Label(
                            "Turn this off temporarily when another app or workflow needs "
                                + "Option-key combinations.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundColor(DS.textSecondary)
                    }

                    Section("Appearance") {
                        HStack(alignment: .center) {
                            Text("Status Bar Icon")
                            Spacer()
                            HStack(spacing: 8) {
                                ForEach(
                                    StatusBarIconChoice.allCases,
                                    id: \.self
                                ) { choice in
                                    StatusBarIconChoiceButton(
                                        choice: choice,
                                        isSelected: vm.statusBarIcon == choice,
                                        action: { vm.statusBarIcon = choice })
                                }
                            }
                        }
                        .onChange(of: vm.statusBarIcon) { _, _ in onSave() }
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text("Chap \(Defaults.appVersion)")
                    .font(.caption)
                    .foregroundColor(DS.textSecondary)
            }
            .padding(.bottom, 12)
        }
        .background(DS.surfaceBg)
    }
}
